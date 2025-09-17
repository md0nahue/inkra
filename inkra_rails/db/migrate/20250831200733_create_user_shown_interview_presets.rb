class CreateUserShownInterviewPresets < ActiveRecord::Migration[7.1]
  def change
    create_table :user_shown_interview_presets do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :interview_preset, null: false, foreign_key: true, index: false
      t.datetime :shown_at, null: false
      
      t.timestamps
    end
    
    add_index :user_shown_interview_presets, [:user_id, :interview_preset_id], 
              unique: true, name: 'index_user_shown_interview_presets_unique'
    add_index :user_shown_interview_presets, :shown_at
    add_index :user_shown_interview_presets, :user_id
  end
end
