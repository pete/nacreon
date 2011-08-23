module Nacreon::Model
	# An Instance represents a single process that serves the app over a
	# port it's listening on.  The idea is that we have N instances (running
	# Unicorn/Rainbows/etc.) that can be routed to (or, for now, accessed
	# directly).
	#
	# Note that process management is not done by Model::Instance.  It's for
	# bookkeeping, so that we know what's running where.  Actual management is
	# done by the AppManager.
	class Instance < Sequel::Model
		include Mixin
		set_dataset :instance

		ValidStatuses = [
			"ready",   # The instance may be started
			"started", # It has started, but may not be live yet
			"live",    # It is up and running last time we checked
			"marked",  # It may now be killed

			"dead",    # It died of possibly mysterious causes

			"killed",  # It was killed (failed to respond, was undeployed, etc.)
		]

		PublicProperties = [
			:name,
			:status,
			:spawned,
			:annotation,
		]

		many_to_one :app
		many_to_one :version

		# We define some methods for each valid status to query and manipulate.
		ValidStatuses.each { |s|
			# Two helpers to find the instances by the given status:
			define_singleton_method("#{s}_dataset") {
				dataset.where(:status => s)
			}
			define_singleton_method(s) { dataset.where(:status => s).to_a }
			# And again where the host is the current host (we use this in the
			# AppManager::Daemon.
			define_singleton_method("#{s}_on_host") { |host|
				dataset.where(:status => s, :host => host)
			}
			
			# A predicate for querying status.
			define_method("#{s}?") { status == s }
			# A method for changing the status.
			define_method("#{s}!") { |a = nil|
				self.status = s
				self.annotation = a
				save
			}
		}

		def self.on_dataset host
			dataset.where :host => host
		end

		def self.on host
			on_dataset(host).to_a
		end

		def name
			t = spawned.strftime('%F %R') rescue '(Unknown time)'
			"#{app.name}[#{version.name}, started #{t}]"
		end

		def address
			"#{host}:#{port}"
		end

		def before_create
			self.spawned = Time.now
			super
		end

		def before_save
			if status == 'dead' || status == 'killed'
				# TODO:  Rename the 'killed' field to 'stopped'.
				self.killed = Time.now
			end
			super
		end

		def validate
			unless ValidStatuses.include?(status)
				errors.add(:status, "is not valid")
			end

			super
		end
	end
end
