class CreateUserDataExports < ActiveRecord::Migration[7.1]
  def change
    create_table :user_data_exports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.string :s3_key
      t.integer :file_count, default: 0
      t.bigint :total_size_bytes, default: 0
      t.integer :highest_project_id
      t.integer :highest_audio_segment_id
      t.datetime :expires_at

      t.timestamps
    end
    
    add_index :user_data_exports, [:user_id, :created_at]
    add_index :user_data_exports, :status
    add_index :user_data_exports, :expires_at
  end
end
