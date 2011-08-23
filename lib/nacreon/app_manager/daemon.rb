require 'socket'

module Nacreon::AppManager
	# The AppManager daemon class runs the AppManager's loop.  AppManager
	# manages the apps' deployment logic, and Daemon manages the logic of
	# looping, selecting jobs to take, etc.
	# TODO:  The Daemon assumes that it is the only one running.  In the
	# future, it will assume that it is the only one running per machine.
	class Daemon
		include Nacreon
		attr_accessor :log

		# Create an instance of the Daemon.  It requires a logger instance
		# roughly compatible with Logger.
		def initialize logger = Nacreon.log
			self.log = logger
		end

		# Executes the main loop, from which there is no return.  All
		# Exceptions will be caught and logged as errors.
		def main_loop
			begin
				loop {
					iterate
					log.debug "Finished iteration; sleeping for #{sleep_time}s."
					sleep sleep_time
				}
			rescue Exception => e
				# We want to avoid crashing if at all possible, so we catch
				# everything, log it, sleep (to avoid thrashing or flooding the
				# logs completely if the error persists), and go back to the
				# main loop.
				log.error("#{self.class.inspect}'s main loop crashed " \
						  "with #{e.inspect} at #{e.backtrace[0]}!")
				sleep(sleep_time * 10)
				retry
			end
		end

		# Makes one run through the main loop.
		def iterate
			# First off, if we can free up resources, we should do that first.
			Model::Instance.marked_on_host(AppManager.host).each { |i|
				AppManager.kill_marked i
			}

			# We do this right after to avoid too long a wait for instances to
			# spin up.
			Model::Instance.started_on_host(AppManager.host).each { |i|
				AppManager.check_startup i
			}

			Model::Instance.live_on_host(AppManager.host).each { |i|
				AppManager.check_running i
			}

			# TODO:  ready_dataset needs a .where(:some_criterion => foo); JG
			# suggests a distributed hashing algorithm for selecting instances,
			# which from the sound of it would avoid collisions.  The goal is
			# to distribute load semi-optimally for capacity, ideally without
			# requiring that the nodes communicate with or monitor each other.
			i = Model::Instance.ready_dataset.first
			if i
				AppManager.spin_up i
			end
		end

		# A calculation of the amount of time this particular daemon should
		# sleep between iterations.
		def sleep_time
			# TODO:  Hard-coded for now.  See doc/app_manager.rdoc for some
			# thoughts on this.
			1
		end
	end
end
