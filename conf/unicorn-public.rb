listen "0.0.0.0:4999"
worker_processes 4
pid "/var/run/unicorn/nacreon.pid"
stderr_path "/var/log/unicorn/nacreon.log"
stdout_path "/var/log/unicorn/nacreon.log"
preload_app true
after_fork { |s,w|
	        Nacreon.init until Sequel::Model.db.test_connection
}
