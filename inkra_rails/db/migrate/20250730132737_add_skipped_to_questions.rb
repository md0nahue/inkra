class AddSkippedToQuestions < ActiveRecord::Migration[7.1]
  def change
    add_column :questions, :skipped, :boolean, default: false, null: false
  end
end
