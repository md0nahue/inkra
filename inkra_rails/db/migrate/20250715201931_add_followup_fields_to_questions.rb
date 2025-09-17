class AddFollowupFieldsToQuestions < ActiveRecord::Migration[7.1]
  def change
    add_reference :questions, :parent_question, null: true, foreign_key: { to_table: :questions }
    add_column :questions, :is_follow_up, :boolean, default: false, null: false
  end
end
