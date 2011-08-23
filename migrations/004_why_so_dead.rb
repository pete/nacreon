class WhySoDead < Sequel::Migration
	def up
		alter_table(:instance) {
			add_column :annotation, String
		}
	end

	def down
		drop_column :instance, :annotation
	end
end
