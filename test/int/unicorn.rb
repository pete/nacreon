Configurator::DEFAULTS[:logger].level = Logger::WARN
listen "127.0.0.1:21245"
stdout_path 'tmp/integration.log'
stderr_path 'tmp/integration.log'
worker_processes 4
preload_app true
after_fork { |s,w| Nacreon.init until Sequel::Model.db.test_connection }
