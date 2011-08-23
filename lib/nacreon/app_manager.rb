require 'nacreon/model'
require 'socket'

module Nacreon
	# For the time being, this is a regular module, since it's all running on
	# the same machine.  At some point, though, it'll become a proxy object for
	# talking to the App Manager Proper.
	module AppManager
		class Error < StandardError; end
		extend self

		def log
			Nacreon.log
		end

		# Deploys a Version, adds an Instance to the DB.
		def deploy version
			prep_version version
			instance = version.instantiate
			spin_up instance
		end

		# Prepares a version of an app for deployment, including unpacking the
		# code, etc.
		def prep_version version
			app = version.app
			app_root = app_root_for app, version

			tarball = tarball_for version

			unless File.exist?(tarball)
				raise AppManager::Error,
					"#{tarball} doesn't exist, can't deploy."
			end

			dir = "#{app_root}/code"
			make_dirs app_root
			unpack_app(version, dir) or return false
			true
		end

		# Spins up an instance on this host.
		def spin_up i
			log.info "Spinning up: #{idesc i}"
			
			sock = nil
			begin
				port, sock = find_an_open_port
				sock.close rescue nil
				dir = "#{app_root_for(i.app, i.version)}/code"
				pid = run_server dir, port
				i.host, i.port, i.pid = host, port, pid
				i.started!
			rescue Exception => e # TODO: Punting
				$stderr.puts e.inspect, *e.backtrace
				i.dead!
			ensure
				sock.close rescue nil if sock
			end
			i
		end

		# Returns the hostname with which the AppManager should stamp instances
		# it creates.
		def host
			# FIXME:  This is both a hack and the best way I know to do this.
			Socket.getaddrinfo(Socket.gethostname, 0)[0][2]
		end

		def startup_timeout
			3
		end

		def kill_marked i
			if instance_running? i
				Process.kill 15, i.pid rescue nil
				# And, although we don't want to wait for it here (and it's not
				# necessary to wait anyway), we should give the process a bit
				# of time to clean up if necessary, but don't let it take
				# forever.
				Thread.new {
					j = i.dup
					sleep 2
					Process.kill 9, j.pid
				}
				nil
			end
			kill i, "Killed by user"
		end

		def check_startup i
			if instance_running? i
				if instance_listening? i
					log.info "Up:  #{idesc i}"
					i.live!
				elsif((Time.now.to_f - i.spawned) > startup_timeout)
					  log.warn "Failed to start listening: #{idesc i}"
					  kill i, "Timeout exceeded."
				end
			else
				i.dead!
			end
		end

		def check_running i
			if instance_running? i
				if !instance_listening? i
					log.warn "Crashed:  #{idesc i}"
					kill i, "Stopped listening."
					# TODO:  Restart?
				end
			else
				log.warn "Failed to start:  #{idesc i}!"
				i.dead! "Failed to start."
				# TODO:  Restart?
			end
		end

		# Kills an instance (marking it with why it was killed) and updates its
		# status in the DB.  +why+ is a free-form string, intended for
		# diagnostic purposes.
		def kill instance, why
			begin
				Process.kill 15, instance.pid
				sleep 0.2
				Process.kill 9, instance.pid
			rescue Errno::ESRCH
				# We can safely ignore it if the thing has already died.
			end
			instance.killed! why
			reconfigure_rproxies
		end

		# Kills all instances running on the current host.  Be really, really
		# careful with this.
		def kill_everybody! why
			Model::Instance.live_on_host(host).each { |i| kill i, why }
		end

		# Returns true if the instance appears to be a valid, live process
		# (without regard for whether or not it is functioning correctly).  The
		# instance must be running on this host, or an exception is raised.
		def instance_running? instance
			unless instance.host == host
				raise ArgumentError, "Cannot check instances on remote hosts!"
			end
			# This seems like a reasonable way to check without `ps ...`.
			File.directory?("/proc/#{instance.pid}")
		end

		# Returns true if the specified instance is listening on its designated
		# port.  Requires that the instance be running on the same machine as
		# this process.
		def instance_listening? instance
			# /proc/$pid/net/tcp{,6} give information about the open TCP
			# sockets, and the first field is address:port, in hex.  I do not
			# know of a better way to determine if a given process is listening
			# on a given port; there's also `lsof -p $pid -P` and grep for the
			# port number, but that feels sloppier.  netstat(8) won't tell you
			# about pids, so it could only be used to tell if *something* was
			# listening on the port, and ditto for ss(8).
			hport = '%X' % instance.port

			files = [
				"/proc/#{instance.pid}/net/tcp",
				"/proc/#{instance.pid}/net/tcp6",
			].select { |f| File.exist? f }

			return nil if files.empty?

			files.each { |f|
				File.readlines(f).find { |l|
					if l.strip.split(/\s+/)[1].split(/:/)[1] == hport
						return true
					end
				}
			}
			false
		end

		# Returns a filename for the tarball of a given version.
		def tarball_for version
			arf = app_root_for(version.app, version)
			File.join arf, 'app.tgz'
		end

		def save_tarball version, tarball
			filename = tarball_for version
			FileUtils.mkdir_p File.dirname(filename)
			(File.open(filename, 'w') << tarball).close
			filename
		end

		# Returns the absolute path to the deployed version of the application.
		def app_root_for app, version
			"#{Nacreon::Config.deploy_root}/#{app.name}/#{version.name}"
		end

		def start_rproxies
			RProxy.rewrite_config_for Model::App.all
			begin
				RProxy.start!
			rescue StandardError
			end
		end

		def reconfigure_rproxies
			RProxy.rewrite_config_for Model::App.all
			RProxy.restart!
		end

		private

		def make_dirs root
			unless File.directory? Nacreon::Config.deploy_root
				FileUtils.mkdir_p Nacreon::Config.deploy_root
				File.chmod 01777, Nacreon::Config.deploy_root
			end

			%w(code pids logs).each { |dir|
				FileUtils.mkdir_p "#{root}/#{dir}"
				# FIXME:  Leaving this out for debugging, for the time being.
				# File.chmod 0700, "#{root}/#{dir}"
			}
		end

		def run_server dir, port
			config = Nacreon::Config.unicorn_conf_file

			pid = fork {
				Dir.chdir dir
				(3..1024).each { |fd| IO.for_fd(fd).close rescue nil }

				cmd = "unicorn -E production -p #{port} -c #{config} config.ru"
				if bundler_app? dir
					cmd = "bundle exec #{cmd}"
				end
				exec cmd
			}

			pid
		end

		def unpack_app version, dir
			system("tar xvzf #{tarball_for(version)} -C #{dir}") or return false
			# FIXME:  This takes fer friggin' EVER.  We should do some sort of
			# local gem cache and possibly move this elsewhere.  Putting it
			# into run_server makes the startup timeout excessive.  So I am
			# semi-unsure about where we ought to put this, but here is the
			# wrong place.
			if bundler_app? dir
				system("cd #{dir} && bundle install --path vendor") or \
					return false
			end

			true
		end

		def find_an_open_port
			# FIXME:  Extra race-conditiony, the whole thing.
			host = Socket.gethostname
			used = Model::Instance.where(:host => host, :killed => nil).
				all.map { |i| i.port }
			ports = (18000..65535).to_a - used
			ports.each { |p|
				s = nil
				begin
					s = TCPServer.new p
					return [p, s]
				rescue Errno::EADDRINUSE
				end
			}
		end

		# For logging, describes an instance, including information that isn't
		# exposed via, e.g., the REST API.
		def idesc i
			"Instance[#{i.id}] (#{i.address} pid #{i.pid} #{i.name}, "\
				"status #{i.status})"
		end

		def bundler_app? dir
			File.exist?("#{dir}/Gemfile")
		end
	end
end

require 'nacreon/app_manager/rproxy'
