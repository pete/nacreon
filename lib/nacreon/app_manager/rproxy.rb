require 'erb'

module Nacreon
	module AppManager
		# A generic, simple front-end for managing the reverse proxies.
		# We're currently using nginx exclusively, though.
		module RProxy
			extend self

			# Raised when the config file doesn't validate; this is really
			# programmer error and so a little more serious than a regular
			# StandardError, thus the subclassing of Exception.
			class ConfigError < Exception; end
			# Couldn't start the reverse proxy server!
			class StartupError < StandardError; end

			def rewrite_config_for apps
				r = generate_config_for apps
				File.open(config_output_path, 'w') { |f| f.write r }
			end

			# Generates a config file for the specified apps.
			def generate_config_for apps
				r = ERB.new(erb_template).
					result(erb_template_binding(apps, Nacreon::Config.domain,
					                            Nacreon::Config.nginx_port))
				# In case the gsub looks funny, it's there to allow both the
				# template and the output at least semi-readable:
				r.gsub!(/(\n\s+)+\n/, "\n\n")
				r
			end

			def start!
				pid = fork {
					# If nginx is running (and it usually is in the case of
					# unicorn getting 'preload_app false', which is how we do
					# it for dev environments, then it'll get so mad about
					# another nginx having bound to the port already.
					# FIXME?  I think so.
					$stdin.reopen '/dev/null', 'r'
					$stdout.reopen '/dev/null', 'w'
					$stderr.reopen '/dev/null', 'w'
					exec startup_cmd
				}
				Process.detach pid
				pid
			end

			# Restarts the server.
			def restart!
				raise ConfigError unless valid_config?
				raise StartupError, restart_cmd unless system(restart_cmd)
			end

			private

			def startup_cmd
				"nginx -p #{File.dirname(config_output_path)}/ "\
					"-c #{File.basename(config_output_path)}"
			end

			def valid_config?
				system "#{startup_cmd} -t >/dev/null 2>/dev/null"
			end

			def restart_cmd
				"#{startup_cmd} -s reload"
			end

			def config_output_path
				'/tmp/nacreon-nginx.conf'
			end

			def erb_template
				File.read Nacreon::Config.nginx_conf_template
			end

			def erb_template_binding apps, domain, port
				binding
			end
		end
	end
end
