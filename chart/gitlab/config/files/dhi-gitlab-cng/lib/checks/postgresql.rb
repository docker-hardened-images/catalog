# frozen_string_literal: true

require 'yaml'
require 'active_record'

module Checks
  # Perform checks of PostgreSQL dependency.
  # Usage: `Checks::PostgreSQL.run`
  module PostgreSQL
    def self.run
      counter = 1
      passed = false
      until (counter == wait_for_timeout) || passed
        passed = check_all_databases
        sleep sleep_duration unless passed
        counter += 1
      end
      passed
    end

    def self.wait_for_timeout
      ENV['WAIT_FOR_TIMEOUT'].to_i
    end

    def self.sleep_duration
      ENV['SLEEP_DURATION'].to_i
    end

    def self.config_directory
      ENV['CONFIG_DIRECTORY']
    end

    def self.schema_versions_dir
      ENV['SCHEMA_VERSIONS_DIR']
    end

    def self.database_file
      ENV['DATABASE_FILE']
    end

    def self.db_schema_target
      ENV['DB_SCHEMA_TARGET']
    end

    class DatabaseConfig
      include Checks::BypassSchemaVersionCheck

      def initialize(shard_name)
        @shard_name = shard_name
      end

      def check_schema_version
        success = database_schema_version

        puts "Database Schema - #{@shard_name} (#{ActiveRecord::Base.connection_db_config.database})"
        puts 'NOTICE: Database has not been initialized yet.' if @database_versions.empty?
        if bypass_schema_version_check
          puts "WARNING: schema version check bypassed by #{BYPASS_SCHEMA_VERSION_KEY}='#{ENV[BYPASS_SCHEMA_VERSION_KEY]}'"
        end
        pending_migrations = (Set.new(codebase_schema_versions) - Set.new(@database_versions)).length
        puts "NOTICE: There are #{pending_migrations} pending migrations." if pending_migrations > 0

        return true if bypass_schema_version_check && success

        success && !(pending_migrations > 0)
      rescue StandardError => e
        puts "Error checking #{@shard_name}: #{e.message}"
        false
      end

      private

      def database_schema_version
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: 'production', name: @shard_name)
        connection = ActiveRecord::Base.establish_connection(db_config).lease_connection
        schema_migrations_table_name = ActiveRecord::Base.schema_migrations_table_name

        # if connection is bad, we will get an error (rescue below)
        # if table exists, fetch versions.
        table_exists = connection.table_exists?(schema_migrations_table_name)
        @database_versions = []

        if table_exists
          @database_versions =
            connection.select_values("SELECT version FROM #{schema_migrations_table_name}").map(&:to_i)
        end

        if @database_versions.empty?
          puts "WARNING: Problem accessing #{@shard_name} database (#{ActiveRecord::Base.connection_db_config.database})."\
               ' Confirm username, password, and permissions.'
        end

        # Returning false prevents bailing when BYPASS_SCHEMA_VERSION set.
        return !@database_versions.empty? if table_exists

        true
      rescue RuntimeError => e
        puts "Error fetching #{@shard_name} schema: #{e.message}"
        false
      end

      def codebase_schema_versions
        Dir.glob("#{Checks::PostgreSQL.schema_versions_dir}/*").map do |file|
          File.basename(file, '.rb').split('_').first.to_i
        end
      end
    end

    def self.database_configurations
      @@database_configurations ||= ActiveRecord::DatabaseConfigurations
                                    .new(database_yaml)
    end

    def self.database_yaml
      @@database_yaml ||= ActiveSupport::ConfigurationFile.parse(
        File.join(config_directory, database_file)
      )
    end

    def self.production_databases
      db_configs = database_configurations.configs_for(
        env_name: 'production', include_hidden: false
      )
                                          # we filter out the embedding DB as it's schema only
                                          # receives selected migrations and will lag behind
                                          .reject { |db_config| db_config.name == 'embedding' }

      db_configs =
        if db_schema_target == 'geo'
          # TODO: To be removed in 15.0. See https://gitlab.com/gitlab-org/gitlab/-/issues/351946
          # The db_config.name is set to primary when config/database_geo.yml exists and uses a legacy syntax.
          db_configs.find { |db_config| %w[primary geo].include?(db_config.name) }
        else
          db_configs.reject { |db_config| db_config.name == 'geo' }
        end

      Array(db_configs)
    end

    def self.check_all_databases
      ActiveRecord::Base.configurations = database_configurations

      puts "Checking: #{production_databases.map(&:name).join(', ')}"

      results = production_databases.map do |db_config|
        Thread.new do
          DatabaseConfig.new(db_config.name).check_schema_version
        end
      end.map(&:value)

      # Collect the checks that passed.
      results.all?
    end
  end
end
