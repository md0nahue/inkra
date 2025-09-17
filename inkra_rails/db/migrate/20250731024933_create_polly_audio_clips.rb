class CreatePollyAudioClips < ActiveRecord::Migration[7.1]
  def change
    create_table :polly_audio_clips do |t|
      t.references :question, null: false, foreign_key: true
      t.string :s3_key, null: false
      t.string :voice_id, null: false
      t.integer :speech_rate, default: 100
      t.string :language_code, default: 'it-IT'
      t.integer :duration_ms
      t.string :status, default: 'pending', null: false
      t.text :error_message
      
      t.timestamps
    end
    
    add_index :polly_audio_clips, :s3_key, unique: true
    add_index :polly_audio_clips, :status
  end
end
