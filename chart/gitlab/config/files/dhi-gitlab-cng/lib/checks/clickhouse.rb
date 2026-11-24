# frozen_string_literal: true

require 'yaml'
require 'net/http'
require 'click_house/client'

module Checks
  # Perform checks of ClickHouse dependency.
  # Usage: `Checks::ClickHouse.run`
  module ClickHouse
    SCHEMA_MIGRATIONS_TABLE = 'schema_migrations'

    def self.run
      unless raw_config_file_exists?
        log 'INFO: ClickHouse is not configured. Skipping migration checks.'
        return true
      end

      if skip_checks?
        log 'WARN: ClickHouse migration check explicitly skipped. This is NOT recommended for production environments.'
        return true
      end

      # ClickHouse databases map an identifier to a configuration.
      # This can be run only once, so we should not run this within check_all_databases
      configure_databases

      counter = 1
      passed = false
      until (counter == wait_for_timeout) || passed
        passed = check_all_databases
        sleep sleep_duration unless passed
        counter += 1
      end
      passed
    end

    # Explicitly check if checks should be skipped by user configuration:
    # When running tests or other non-production environments, setting the environment variable
    # `SKIP_CLICKHOUSE_SCHEMA_VERSION_CHECK=YesReally` will bypass the schema version check.
    # See: https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/21637
    def self.skip_checks?
      (ENV['SKIP_CLICKHOUSE_SCHEMA_VERSION_CHECK'] || '') == 'YesReally'
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
      ENV['CLICKHOUSE_SCHEMA_VERSIONS_DIR']
    end

    def self.database_file
      ENV['CLICKHOUSE_DATABASE_FILE']
    end

    def self.raw_config_file_exists?
      File.exist?(raw_config_file)
    end

    def self.raw_config_file
      File.join(config_directory, database_file)
    end

    def self.raw_config
      @@raw_config ||= ActiveSupport::ConfigurationFile.parse(raw_config_file).deep_symbolize_keys
    end

    def self.production_databases
      @@production_databases ||= raw_config[:production]
    end

    def self.configure_databases
      if production_databases.empty?
        log 'NOTICE: ClickHouse does not have any production databases configured.'
        return true
      end

      # This is mostly copied as-is from the ClickHouse initializer in the Rails codebase and the README
      # of the click_house-client Ruby gem
      # https://gitlab.com/gitlab-org/gitlab/blob/f4cfdeef153623a826f1bec300b89bfe88d2d70e/config/initializers/click_house.rb#L3-3
      # https://gitlab.com/gitlab-org/ruby/gems/clickhouse-client
      ::ClickHouse::Client.configure do |config|
        production_databases.each do |db_identifier, db_config|
          log "INFO: Configuring ClickHouse DB #{db_identifier}"
          config.register_database(db_identifier,
                                   database: db_config[:database],
                                   url: db_config[:url],
                                   username: db_config[:username],
                                   password: db_config[:password],
                                   variables: db_config[:variables] || {}
          )

          # Use any HTTP client to build the POST request, here we use Net::HTTP
          config.http_post_proc = lambda { |url, headers, body|
            # Query placeholders go to the URI
            params = URI.encode_www_form(body.except('query'))

            uri = URI.parse("#{url}&#{params}")
            request = Net::HTTP::Post.new(uri)

            headers.each do |header, value|
              request[header] = value
            end

            request['Content-type'] = 'application/x-www-form-urlencoded'
            request.body = body['query']

            response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
              http.request(request)
            end

            ::ClickHouse::Client::Response.new(response.body, response.code.to_i, response.each_header.to_h)
          }
        end
      end
    end

    class DatabaseConfig
      include Checks::BypassSchemaVersionCheck

      def initialize(db_identifier, table_name = 'schema_migrations')
        @db_identifier = db_identifier
        @table_name = table_name
      end

      def log(msg)
        Checks::ClickHouse.log(msg)
      end

      def check_schema_version
        log "INFO: ClickHouse - Database #{db_identifier}"

        fetched_database_versions = database_schema_versions
        log 'NOTICE: Database has not been initialized yet.' if @database_versions.empty?

        pending_migrations = (Set.new(codebase_schema_versions) - Set.new(@database_versions)).length
        log "INFO: There are #{pending_migrations} migrations pending."

        log 'FATAL: Database versions could not be fetched' unless fetched_database_versions
        return false unless fetched_database_versions

        if fetched_database_versions && bypass_clickhouse_schema_version_check
          log "INFO: Schema version check bypassed by #{BYPASS_CLICKHOUSE_SCHEMA_VERSION_KEY}='#{ENV[BYPASS_CLICKHOUSE_SCHEMA_VERSION_KEY]}'"
          return true
        end

        fetched_database_versions && pending_migrations.zero?
      rescue StandardError => e
        log "FATAL: Error while checking schema versions for ClickHouse #{db_identifier} DB: #{e.message}"
        false
      end

      private

      def codebase_schema_versions
        Dir.glob("#{Checks::ClickHouse.schema_versions_dir}/#{db_identifier.to_s}/*").map do |file|
          File.basename(file, '.rb').split('_').first.to_i
        end
      end

      def database_schema_versions
        @database_versions = []

        # If schema_migrations table does not exist, then the DB has been created but not yet
        # initialized. Schema check will not fail, allowing migration scripts to run and create
        # this table.
        unless table_exists?
          log 'NOTICE: schema_migrations table does not exist'
          return true
        end

        @database_versions = ::ClickHouse::Client.select("SELECT version FROM #{SCHEMA_MIGRATIONS_TABLE}", db_identifier)
                                                 .map { |v| v['version'].to_i }

        !@database_versions.empty?
      rescue ::ClickHouse::Client::Error => e
        # Exception is returned by ClickHouse in JSON format as per the default configuration.
        # https://clickhouse.com/docs/interfaces/http#valid-output-on-exception-http-streaming
        begin
          parsed_error = JSON.parse(e.message)
          log "FATAL: Error while fetching the database versions for ClickHouse #{db_identifier} DB: #{parsed_error['exception']}"
        rescue JSON::ParserError
          log "FATAL: Unexpected error while fetching the database versions for ClickHouse #{db_identifier} DB: #{e.message}"
        end
        false
      end

      # This block is copied as-is from the gitlab-org/gitlab codebase:
      # https://gitlab.com/gitlab-org/gitlab/blob/fc396a1369fb6562838c2b3e388490989254d979/lib/click_house/connection.rb#L58-59
      def table_exists?
        raw_query = <<~SQL.squish
          SELECT 1 FROM system.tables
          WHERE name = {table_name: String}
        SQL

        placeholders = { table_name: table_name }

        query = ::ClickHouse::Client::Query.new(raw_query: raw_query, placeholders: placeholders)

        ::ClickHouse::Client.select(query, db_identifier).any?
      end

      attr_reader :db_identifier, :db_config, :table_name
    end

    def self.check_all_databases
      results = production_databases.keys.map do |db_identifier|
        Thread.new do
          log "INFO: Checking migration schema state for ClickHouse database #{db_identifier}"
          DatabaseConfig.new(db_identifier).check_schema_version
        end
      end.map(&:value)

      # Collect the checks that passed.
      results.all?
    end

    LOG_PREFIX = 'ClickHouse'

    def self.log(msg)
      puts "[#{LOG_PREFIX}] #{msg}"
    end
  end
end
