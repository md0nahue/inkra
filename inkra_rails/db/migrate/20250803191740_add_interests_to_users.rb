class AddInterestsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :interests, :string, array: true, default: []
    add_index :users, :interests, using: 'gin'
  end
end
