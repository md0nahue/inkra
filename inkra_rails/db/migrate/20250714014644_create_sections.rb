class CreateSections < ActiveRecord::Migration[7.1]
  def change
    create_table :sections do |t|
      t.references :chapter, null: false, foreign_key: true
      t.string :title
      t.integer :order
      t.boolean :omitted

      t.timestamps
    end
  end
end
