class InitSchema < Sequel::Migration
	def up
		create_table(:user) {
			primary_key :id

			# This is the name for logging in, and for organizing SSH keys in
			# gitolite:
			String :name, :null => false, :unique => true
			# It'll be all SSO names (jdoe, etc.) or AT&T IDs (jd1234) at some
			# point.

			# A SHA1 digest of the salt and the hashed pasword:
			String :hashed_password, :null => false, :length => 40
			String :salt, :null => false

			Time :created, :null => false
			Boolean :active, :null => false, :default => false
		}

		create_table(:app) {
			primary_key :id

			foreign_key :owner_id, :user, :key => :id

			String :name, :null => false
		}

		create_table(:version) {
			primary_key :id
			foreign_key :app_id, :app, :key => :id, :null => false
			String :name
		}

		create_table(:instance) {
			primary_key :id

			foreign_key :app_id, :app, :key => :id, :null => false
			foreign_key :version_id, :version, :key => :id, :null => false

			String :host
			Integer :port
			Integer :pid
			String :status, :null => false

			Time :spawned, :null => false

			Time :killed	# NULL for the living
			Time :last_ping	# So we can schedule health checks, etc.
		}
	end

	def down
		drop_table :user, :app, :instance
	end
end
