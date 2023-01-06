class RemoveAccountLoginStats < ActiveRecord::Migration[6.1]
 def up
     drop_table :account_login_stats
   end

   def down
     raise ActiveRecord::IrreversibleMigration
   end
end
