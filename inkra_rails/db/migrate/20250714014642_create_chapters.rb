class CreateChapters < ActiveRecord::Migration[7.1]
  def change
    create_table :chapters do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title
      t.integer :order
      t.boolean :omitted

      t.timestamps
    end
  end
end
