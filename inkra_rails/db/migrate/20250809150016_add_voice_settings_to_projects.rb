class AddVoiceSettingsToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :voice_id, :string
    add_column :projects, :speech_rate, :integer, default: 100
  end
end
