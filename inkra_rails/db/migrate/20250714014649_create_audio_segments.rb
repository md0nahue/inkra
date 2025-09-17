class CreateAudioSegments < ActiveRecord::Migration[7.1]
  def change
    create_table :audio_segments do |t|
      t.references :project, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.string :file_name
      t.string :mime_type
      t.integer :duration_seconds
      t.string :s3_url
      t.string :upload_status

      t.timestamps
    end
  end
end
