require 'digest/sha1'

module Nacreon::Model
	class User < Sequel::Model
		include Mixin
		set_dataset :user

		PublicProperties = [
			:name,
			:created,
			:app_uris,
		]

		def self.random_salt
			rand.to_s[2..-1]
		end

		def self.hash_password salt, pw
			Digest::SHA1.hexdigest "#{salt}#{pw}"
		end

		def self.authenticate name, pw
			u = self[:name => name]
			return unless u && u.active
			return u if hash_password(u.salt, pw) == u.hashed_password
		end

		def before_create
			self.created = Time.now
			self.active = true
			super
		end

		def app_uris
			[] # TODO:  Push this into the resource.
		end

		def password=(pw)
			self.salt = self.class.random_salt
			self.hashed_password = self.class.hash_password salt, pw
			pw
		end

		def validate
			super
			validate_name
			validate_unique :name
		end
	end
end
