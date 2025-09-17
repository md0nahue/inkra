class AddLastAccessedAtToProjectsAndTrackers < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :last_accessed_at, :datetime
    add_column :trackers, :last_accessed_at, :datetime
    
    add_index :projects, :last_accessed_at
    add_index :trackers, :last_accessed_at
  end
end
