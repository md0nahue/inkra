class AddTranscriptionTextToAudioSegments < ActiveRecord::Migration[7.1]
  def change
    add_column :audio_segments, :transcription_text, :text
  end
end
