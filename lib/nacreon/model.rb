require 'sequel/model'

Sequel::Model.raise_on_save_failure = false

# The namespace in which the models are stuffed!
module Nacreon::Model
	# A pile of methods for simplifying the other models.
	module Mixin
		module ClassMethods
			def one_to_many_live_instances
				one_to_many :live_instances,
					:class => Instance,
					:dataset => lambda {
						instances_dataset.where(:status => 'live').
							order(:spawned.desc)
					}

				define_method(:live_instance_count) {
					live_instances_dataset.count
				}
			end
		end

		def self.included klass
			klass.class_eval { extend Mixin::ClassMethods }
		end

		# Converts a model into a Hash containing its PublicProperties.
		def to_hash
			h = {}
			self.class::PublicProperties.each { |p|
				h[p] = send(p)
				if h[p].kind_of? Sequel::Model
					h[p] = h[p].to_hash
				end
			}
			h
		end

		# Serializes a model as a JSON string containing its public properties.
		def to_json(*)
			# to_json needs to not care about arguments with the C extension
			# version of the JSON gem.
			# See json-1.5.1/ext/json/ext/generator/generator.c:902
			to_hash.to_json
		end

		private

		# TODO:  Sequel's validation_helpers plugin (a pleasant surprise) is
		# pretty likely to be useful here; this stuff ought to be re-done as
		# calls to it and 

		# To be called from the validation method, specifies that the named
		# columns must be unique.
		def validate_unique *colnames
			colnames.each { |colname|
				ds = self.class.where colname => send(colname)
				ds.filter!(~{primary_key => send(primary_key)}) unless new?
				if ds.count > 0
					errors.add(colname, 'must be unique.')
				end
			}
		end

		# Makes sure the name column is valid.  We're using it in lotsa places.
		def validate_name
			unless Nacreon::NameRX.match(name)
				errors.add(:name,
					'must contain only letters, numbers, and "-".')
			end
		end
	end
end

%w(
	user 
	instance
	app
	version
).each { |f| require "nacreon/model/#{f}" }
