# frozen_string_literal: true

require 'yaml'
require 'grpc'
require 'active_support/configuration_file'
require 'gitlab/cells/topology_service'

module Checks
  # Perform checks of Topology Service dependency for GitLab Cells.
  # Usage: `Checks::TopologyService.run`
  module TopologyService
    LOG_PREFIX = "TopologyService"

    class TopologyServiceConfigurationError < StandardError; end
    class TopologyServiceUnavailableError < StandardError; end

    def self.run
      if skip_check?
        log 'INFO: Topology service check is disabled (SKIP_TOPOLOGY_SERVICE_CHECK != false). Skipping.'
        return true
      end

      unless cells_enabled?
        log 'INFO: Cells not enabled. Skipping topology service check.'
        return true
      end

      check_topology_service
    end

    # Check is disabled by default for safe rollout.
    # Set SKIP_TOPOLOGY_SERVICE_CHECK=false to enable the check.
    def self.skip_check?
      ENV.fetch('SKIP_TOPOLOGY_SERVICE_CHECK', 'true') != 'false'
    end

    def self.config_directory
      ENV['CONFIG_DIRECTORY'].to_s
    end

    def self.wait_for_timeout
      ENV['WAIT_FOR_TIMEOUT'].to_i
    end

    def self.sleep_duration
      ENV['SLEEP_DURATION'].to_i
    end

    def self.gitlab_config
      @gitlab_config ||= ActiveSupport::ConfigurationFile.parse(
        File.join(config_directory, 'gitlab.yml')
      )
    end

    def self.cell_config
      gitlab_config.dig('production', 'cell') || {}
    end

    def self.cells_enabled?
      cell_config['enabled'] == true
    end

    def self.cell_id
      cell_config['id']
    end

    def self.topology_service_config
      cell_config['topology_service_client'] || {}
    end

    def self.topology_service_address
      topology_service_config['address']
    end

    def self.tls_enabled?
      topology_service_config.dig('tls', 'enabled') == true
    end

    def self.grpc_timeout
      ENV.fetch('TOPOLOGY_SERVICE_GRPC_TIMEOUT', 5).to_i
    end

    def self.secrets_directory
      ENV.fetch('GITLAB_SECRETS_DIR', '/etc/gitlab')
    end

    def self.resolve_cert_path(configured_path)
      return configured_path if configured_path && File.readable?(configured_path)

      return unless configured_path

      basename = File.basename(configured_path)
      dirname = File.basename(File.dirname(configured_path))
      fallback = File.join(secrets_directory, dirname, basename)

      if File.readable?(fallback)
        log "INFO: Certificate not found at #{configured_path}, using fallback #{fallback}"
        return fallback
      end

      log "WARN: Certificate not found at #{configured_path} or fallback #{fallback}"
      nil
    end

    def self.service_credentials
      return :this_channel_is_insecure unless tls_enabled?

      ca_file = resolve_cert_path(topology_service_config['ca_file'])
      key_file = resolve_cert_path(topology_service_config['private_key_file'])
      cert_file = resolve_cert_path(topology_service_config['certificate_file'])

      unless key_file && cert_file
        log "WARN: mTLS key/cert files not found, falling back to server-only TLS"
        return GRPC::Core::ChannelCredentials.new
      end

      ca_cert = ca_file ? File.read(ca_file) : nil
      GRPC::Core::ChannelCredentials.new(ca_cert, File.read(key_file), File.read(cert_file))
    rescue Errno::EACCES, Errno::ENOENT => e
      log "ERROR: Failed to read certificate files: #{e.message}"
      raise
    end

    def self.check_topology_service
      address = topology_service_address
      unless address
        log 'ERROR: Topology service address not configured'
        log 'ERROR: Configuration error - this is a hard failure. Cannot proceed.'
        return false
      end

      log "INFO: Checking topology service at #{address}"

      attempt = 1
      max_attempts = wait_for_timeout

      loop do
        result = attempt_cell_check(address)

        # Hard failure - stop immediately
        return false if result == false

        # Success - we're done
        if result == true
          log 'INFO: Cell validation passed'
          return true
        end

        # Soft failure (nil) - retry if we have attempts left
        attempt += 1
        if attempt > max_attempts
          log 'WARN: Topology service unavailable after retries. Proceeding with soft failure.'
          log 'WARN: This may affect ~5% of operations (write operations requiring topology service).'
          return true
        end

        log "INFO: Retrying... (attempt #{attempt}/#{max_attempts})"
        sleep sleep_duration
      end
    end

    def self.attempt_cell_check(address)
      check_cell!(address)
      true
    rescue TopologyServiceConfigurationError => e
      log "ERROR: #{e.message}"
      log 'ERROR: Configuration error - this is a hard failure. Cannot proceed.'
      false
    rescue TopologyServiceUnavailableError => e
      log "WARN: #{e.message}"
      nil
    rescue StandardError => e
      log "WARN: Unexpected error: #{e.class} - #{e.message}"
      nil # Treat as soft failure, allow retry
    end

    def self.check_cell!(address)
      raise TopologyServiceConfigurationError, 'Cell ID not configured' unless cell_id

      stub = Gitlab::Cells::TopologyService::CellService::Stub.new(address, service_credentials)
      request = Gitlab::Cells::TopologyService::GetCellRequest.new(cell_id: cell_id)
      response = stub.get_cell(request, deadline: Time.now + grpc_timeout)

      cell_info = response.cell_info
      raise TopologyServiceConfigurationError, "Cell '#{cell_id}' returned no cell info" unless cell_info

      if cell_info.id.to_s != cell_id.to_s
        raise TopologyServiceConfigurationError, "Cell ID mismatch. Expected: #{cell_id}, Got: #{cell_info.id}"
      end

      log "INFO: Cell '#{cell_id}' validated (address: #{cell_info.address})"
    rescue GRPC::NotFound
      raise TopologyServiceConfigurationError, "Cell '#{cell_id}' not found in topology service"
    rescue GRPC::Unavailable => e
      raise TopologyServiceUnavailableError, "GetCell request failed - service unavailable: #{e.message}"
    rescue GRPC::DeadlineExceeded
      raise TopologyServiceUnavailableError, 'GetCell request timed out'
    rescue GRPC::PermissionDenied, GRPC::Unauthenticated => e
      raise TopologyServiceConfigurationError, "Authentication/authorization failed (check mTLS certificates): #{e.message}"
    rescue GRPC::BadStatus => e
      raise TopologyServiceUnavailableError, "GetCell request failed: #{e.class} - #{e.message}"
    end

    def self.log(msg)
      puts "[#{LOG_PREFIX}] #{msg}"
    end
  end
end
