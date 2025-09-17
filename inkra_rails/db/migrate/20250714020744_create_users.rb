class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :refresh_token_digest
      t.boolean :is_premium, default: false, null: false
      t.datetime :subscription_expires_at
      t.string :revenuecat_subscriber_id

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :revenuecat_subscriber_id, unique: true
  end
end
