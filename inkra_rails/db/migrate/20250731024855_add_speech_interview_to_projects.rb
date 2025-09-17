class AddSpeechInterviewToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :is_speech_interview, :boolean, default: false, null: false
  end
end
