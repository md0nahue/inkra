class CreateTrackers < ActiveRecord::Migration[7.1]
  def change
    create_table :trackers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :sf_symbol_name
      t.string :color_hex

      t.timestamps
    end
  end
end
