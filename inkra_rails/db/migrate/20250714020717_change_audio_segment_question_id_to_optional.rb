class ChangeAudioSegmentQuestionIdToOptional < ActiveRecord::Migration[7.1]
  def change
    change_column_null :audio_segments, :question_id, true
  end
end
