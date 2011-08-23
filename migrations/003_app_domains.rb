class AppDomains < Sequel::Migration
	def up
		alter_table(:app) {
			add_column :domain_name, String
		}
	end

	def down
		drop_column :app, :domain_name
	end
end
