%w(
	watts
	json
	sequel
	fileutils
	syslog_logger
).each &method(:require)

module Nacreon
	# Filesystem- and domain-safe name regex:  lower-case letters, numbers, and
	# '-', so no problems with case sensitivity or odd characters.
	NameRX = /^[-0-9a-z]+$/
	URLSafeRX = /^[-0-9a-zA-Z\.]+$/

	class << self; attr_accessor :log; end

	def self.init
		# First off, we need to load the configuration file:
		Nacreon::Config.load

		# Before the models are loaded, we need to connect to the DB:
		Sequel::Model.db = Sequel.connect Nacreon::Config.db

		log ||= SyslogLogger.new('nacreon')
	end
end

require 'nacreon/config'
Nacreon.init

%w(
	nacreon/resource
	nacreon/model
	nacreon/app_manager
	nacreon/app
).each &method(:require)
