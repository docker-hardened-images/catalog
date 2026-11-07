# frozen_string_literal: true

module Checks
  module BypassSchemaVersionCheck
    BYPASS_SCHEMA_VERSION_KEY = 'BYPASS_SCHEMA_VERSION'
    BYPASS_CLICKHOUSE_SCHEMA_VERSION_KEY = 'BYPASS_CLICKHOUSE_SCHEMA_VERSION'

    def bypass_schema_version_check
      downcase_value = ENV[BYPASS_SCHEMA_VERSION_KEY].to_s.downcase

      return false if downcase_value.empty?

      downcase_value != 'false' && downcase_value != '0'
    end

    def bypass_clickhouse_schema_version_check
      downcase_value = ENV[BYPASS_CLICKHOUSE_SCHEMA_VERSION_KEY].to_s.downcase

      # We bypass the ClickHouse schema version check by default until the next required stop along the upgrade path.
      return true if downcase_value.empty?

      downcase_value != 'false' && downcase_value != '0'
    end
  end
end
