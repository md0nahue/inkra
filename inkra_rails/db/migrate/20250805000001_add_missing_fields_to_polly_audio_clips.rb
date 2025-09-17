class AddMissingFieldsToPollyAudioClips < ActiveRecord::Migration[7.1]
  def change
    add_column :polly_audio_clips, :content_type, :string
    add_column :polly_audio_clips, :request_characters, :integer
    
    # Change default language to English
    change_column_default :polly_audio_clips, :language_code, 'en-US'
  end
end