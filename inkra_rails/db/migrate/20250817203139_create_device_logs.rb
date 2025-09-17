class CreateDeviceLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :device_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :s3_url
      t.string :device_id
      t.string :build_version
      t.string :os_version
      t.datetime :uploaded_at
      t.string :log_type

      t.timestamps
    end
  end
end
