require 'json'
require 'etc'

module Nacreon
	module Config
		ConfigFile = %W(
			#{ENV['NACREON_CONF']}
			#{ENV['HOME']}/.nacreon.json
			/etc/nacreon.json
			./nacreon.json
		).select { |fn| File.exist? fn }.first

		class << self; attr_accessor :config, :loaded; end

		def self.load(fn = nil, force = false)
			fn ||= ConfigFile
			return false if(fn.nil? || (!force && loaded))

			self.config = JSON.parse File.read(fn)
			# TODO:  When the config solidifies reasonably, get rid of the
			# overly metaprogrammed bits here, and replace with regular
			# methods.  It's just a little easier for now to be able to add
			# values to the config file and have the methods appear out of
			# nowhere.
			config.each { |k,v|
				class << self; self; end.module_eval {
					define_method(k) { v }
				}
			}

			self.loaded = true
		end

		# Defaults; they get over-written by the load method if specified in
		# the config file.

		def self.unicorn_conf_file
			# TODO:  We'll likely be deploying apps using regular Rack, since
			# nginx is being used as a reverse proxy.
			File.join(resource_dir, "unicorn-apps.rb")
		end

		def self.nginx_conf_template
			File.join(resource_dir, "nginx.conf.erb")
		end

		def self.nginx_port
			"8080"
		end

		def self.resource_dir
			File.expand_path("#{File.dirname(__FILE__)}/../../conf/")
		end

		def self.domain
			# This is fine for testing purposes, but you'll definitely need to
			# override this for deploys.
			'localhost'
		end

		def self.deploy_root
			"/srv/nacreon-instances"
		end
	end
end

Nacreon::Config.load
