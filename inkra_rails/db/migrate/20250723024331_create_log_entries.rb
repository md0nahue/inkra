class CreateLogEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :log_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tracker, null: false, foreign_key: true
      t.datetime :timestamp_utc
      t.text :transcription_text
      t.text :notes
      t.string :audio_file_url
      t.integer :duration_seconds
      t.string :status

      t.timestamps
    end
  end
end
