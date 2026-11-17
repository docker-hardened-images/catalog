# frozen_string_literal: true

# Load "path" as a rackup file.
#
# The default is "config.ru".
#
rackup '/srv/gitlab/config.ru'
pidfile "#{ENV['HOME']}/puma.pid"
state_path "#{ENV['HOME']}/puma.state"

stdout_redirect '/srv/gitlab/log/puma.stdout.log',
  '/srv/gitlab/log/puma.stderr.log',
  true

# Configure "min" to be the minimum number of threads to use to answer
# requests and "max" the maximum.
#
# The default is "0, 16".
#
threads (ENV['PUMA_THREADS_MIN'] ||= '1').to_i , (ENV['PUMA_THREADS_MAX'] ||= '16').to_i

# By default, workers accept all requests and queue them to pass to handlers.
# When false, workers accept the number of simultaneous requests configured.
#
# Queueing requests generally improves performance, but can cause deadlocks if
# the app is waiting on a request to itself. See https://github.com/puma/puma/issues/612
#
# When set to false this may require a reverse proxy to handle slow clients and
# queue requests before they reach puma. This is due to disabling HTTP keepalive
queue_requests false

# Bind the server to "url". "tcp://", "unix://" and "ssl://" are the only
# accepted protocols.

bind_ip6 = ENV['BIND_IP6'] == 'true'
listen_local_addr = bind_ip6 ? '[::1]' : '127.0.0.1'
listen_all_addr = bind_ip6 ? '[::]' : '0.0.0.0'

# We want to provide the ability to enable individually control HTTP (`INTERNAL_PORT`)
# HTTPS (`SSL_INTERNAL_PORT`):
#
# 1. HTTP on, HTTPS on: Since `INTERNAL_PORT` is configured, we listen on it.
# 2. HTTP on, HTTPS off: If we don't specify either port, we default to HTTP
#    because SSL requires a certificate and key to work.
# 3. HTTP off, HTTPS on: `SSL_INTERNAL_PORT` is enabled but
#   `INTERNAL_PORT` is not set.
http_port = ENV['INTERNAL_PORT'] || '8080'
http_addr =
  if ENV['INTERNAL_PORT'] || (!ENV['INTERNAL_PORT'] && !ENV['SSL_INTERNAL_PORT'])
    listen_all_addr
  else
    # If HTTP is disabled, we still need to listen to localhost for health checks.
    listen_local_addr
  end

bind "tcp://#{http_addr}:#{http_port}"

control_port = ENV['PUMA_CONTROL_PORT'] || '9293'
activate_control_app "tcp://#{listen_local_addr}:#{control_port}", { no_token: true, data_only: true }

if ENV['SSL_INTERNAL_PORT']
  ssl_params = {
    cert: ENV['PUMA_SSL_CERT'],
    key: ENV['PUMA_SSL_KEY'],
  }

  ssl_params[:ca] = ENV['PUMA_SSL_CLIENT_CERT'] if ENV['PUMA_SSL_CLIENT_CERT']
  ssl_params[:key_password_command] = ENV['PUMA_SSL_KEY_PASSWORD_COMMAND'] if ENV['PUMA_SSL_KEY_PASSWORD_COMMAND']
  ssl_params[:ssl_cipher_filter] = ENV['PUMA_SSL_CIPHER_FILTER'] if ENV['PUMA_SSL_CIPHER_FILTER']
  ssl_params[:verify_mode] = ENV['PUMA_SSL_VERIFY_MODE'] || 'none'

  ssl_bind listen_all_addr, ENV['SSL_INTERNAL_PORT'], ssl_params
end

worker_count = (ENV['WORKER_PROCESSES'] ||= '3').to_i
workers worker_count

require "/srv/gitlab/lib/gitlab/cluster/lifecycle_events"

if Gem::Version.new(Puma::Const::PUMA_VERSION) < Gem::Version.new('7.0')
  Gitlab::Cluster::LifecycleEvents.set_puma_options @config.options

  on_restart do
    # Signal application hooks that we're about to restart
    Gitlab::Cluster::LifecycleEvents.do_before_master_restart
  end

  on_worker_boot do
    # Signal application hooks of worker start
    Gitlab::Cluster::LifecycleEvents.do_worker_start
  end

  on_worker_shutdown do
    # Signal application hooks that a worker is shutting down
    Gitlab::Cluster::LifecycleEvents.do_worker_stop
  end
else
  Gitlab::Cluster::LifecycleEvents.set_puma_worker_count(worker_count)

  before_restart do
    # Signal application hooks that we're about to restart
    Gitlab::Cluster::LifecycleEvents.do_before_master_restart
  end

  before_worker_boot do
    # Signal application hooks of worker start
    Gitlab::Cluster::LifecycleEvents.do_worker_start
  end

  before_worker_shutdown do
    # Signal application hooks that a worker is shutting down
    Gitlab::Cluster::LifecycleEvents.do_worker_stop
  end
end

before_fork do
  # Signal application hooks that we're about to fork
  Gitlab::Cluster::LifecycleEvents.do_before_fork
end

# Preload the application before starting the workers; this conflicts with
# phased restart feature. (off by default)
preload_app!

tag 'gitlab-puma-worker'

# Verifies that all workers have checked in to the master process within
# the given timeout. If not the worker process will be restarted. Default
# value is 60 seconds.
#
worker_timeout (ENV['WORKER_TIMEOUT'] ||= '60').to_i

worker_check_interval Integer(ENV.fetch('PUMA_WORKER_CHECK_INTERVAL', '5'))

# https://github.com/puma/puma/blob/master/5.0-Upgrade.md#lower-latency-better-throughput
wait_for_less_busy_worker (ENV['PUMA_WAIT_FOR_LESS_BUSY_WORKER'] ||= '0.001').to_f

# Use json formatter
require "/srv/gitlab/lib/gitlab/puma_logging/json_formatter"

json_formatter = Gitlab::PumaLogging::JSONFormatter.new
log_formatter do |str|
  json_formatter.call(str)
end

require "/srv/gitlab/lib/gitlab/puma/error_handler"

error_handler = Gitlab::Puma::ErrorHandler.new(ENV['RAILS_ENV'] == 'production')

lowlevel_error_handler do |ex, env, status_code|
  error_handler.execute(ex, env, status_code)
end
