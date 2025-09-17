class MakeS3KeyNullableInPollyAudioClips < ActiveRecord::Migration[7.1]
  def change
    change_column_null :polly_audio_clips, :s3_key, true
  end
end
