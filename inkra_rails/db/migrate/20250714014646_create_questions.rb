class CreateQuestions < ActiveRecord::Migration[7.1]
  def change
    create_table :questions do |t|
      t.references :section, null: false, foreign_key: true
      t.text :text
      t.integer :order

      t.timestamps
    end
  end
end
