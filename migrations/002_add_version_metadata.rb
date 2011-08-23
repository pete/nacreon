class AddVersionMetadata < Sequel::Migration
	def up
		alter_table(:version) {
			add_column :created, Time, :null => false, :default => Time.at(0)
		}
	end

	def down
		drop_column :version, :created
	end
end

