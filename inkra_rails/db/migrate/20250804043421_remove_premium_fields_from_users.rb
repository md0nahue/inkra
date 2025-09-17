class RemovePremiumFieldsFromUsers < ActiveRecord::Migration[7.1]
  def change
    remove_column :users, :is_premium, :boolean
    remove_column :users, :subscription_expires_at, :datetime
    remove_column :users, :revenuecat_subscriber_id, :string
  end
end
