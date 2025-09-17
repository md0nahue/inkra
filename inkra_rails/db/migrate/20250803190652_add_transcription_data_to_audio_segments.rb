class AddTranscriptionDataToAudioSegments < ActiveRecord::Migration[7.1]
  def change
    add_column :audio_segments, :transcription_data, :jsonb
  end
end
