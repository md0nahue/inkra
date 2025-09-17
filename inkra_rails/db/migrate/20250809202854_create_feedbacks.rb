class CreateFeedbacks < ActiveRecord::Migration[7.1]
  def change
    create_table :feedbacks do |t|
      t.references :user, null: false, foreign_key: true
      t.text :feedback_text, null: false
      t.string :feedback_type, default: 'general'
      t.string :email
      t.boolean :resolved, default: false
      t.text :admin_notes

      t.timestamps
    end
    
    add_index :feedbacks, :feedback_type
    add_index :feedbacks, :resolved
    add_index :feedbacks, :created_at
  end
end
