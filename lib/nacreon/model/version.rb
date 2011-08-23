module Nacreon::Model
	# A deployable version of an application.
	class Version < Sequel::Model
		include Mixin
		set_dataset Sequel::Model.db[:version].order { created.desc }

		many_to_one :app
		one_to_many :instances
		one_to_many_live_instances

		PublicProperties = [
			:name,
			:created,
			:owner_name,
			:app_name,
			:live_instance_count,
		]

		def before_create
			self.created = Time.now
		end

		def owner_name
			app.owner_name
		end

		def app_name
			app.name
		end

		def live_instance_count
			live_instances_dataset.count
		end

		def instantiate
			i = Instance.new :status => 'ready', :app => app
			add_instance i
			i.save
			i
		end
	end
end
