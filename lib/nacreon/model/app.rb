module Nacreon::Model
	class App < Sequel::Model
		include Mixin
		set_dataset :app

		many_to_one :owner, :class => User
		one_to_many :instances
		one_to_many :versions
		one_to_many_live_instances

		PublicProperties = [
			:owner_name,
			:name,
			#:max_instances,
			#:min_instances,
			:latest_version,
			:live_instances,
			:domain_name,
		]

		# Returns whether or not the specified user has permission to do things
		# to this app.
		def permissible? user
			# For now, the only user with permissions to do things to an app is
			# the owner.
			owner_id == user.id
		end

		def validate
			super

			validate_name
			validate_unique :name
			errors.add(:name, "can't be empty.") if(name.nil? || name.empty?)

			if @bad_owner_name
				errors.add(:owner_name, "not found: #{@bad_owner_name}")
			end

			errors.add(:owner_name, "can't be blank.") unless owner
		end

		# Adds a version with the specified name to the app.
		def add_version_named vname
			v = versions_dataset[:name => vname]
			unless v
				v = Version.new(:name => vname)
				add_version v
				v.save
			end
			v
		end

		def version_names
			versions.map(&:name)
		end

		def latest_version
			versions_dataset.order { created.desc }.first
		end

		# The version with the most recently deployed live instance is
		# considered the current version.
		def current_version
			li = live_instances_dataset.first
			li.version if li
		end

		def owner_name
			owner.name
		end

		def owner_name=(n)
			owner = User[:name => n]
			if owner.nil?
				@bad_owner_name = n
				return
			end

			self.owner = owner
		end
	end
end
