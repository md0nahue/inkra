class AddOmittedToQuestions < ActiveRecord::Migration[7.1]
  def change
    add_column :questions, :omitted, :boolean, default: false, null: false
  end
end
