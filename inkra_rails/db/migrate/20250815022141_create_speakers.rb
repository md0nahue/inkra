class CreateSpeakers < ActiveRecord::Migration[7.1]
  def change
    create_table :speakers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email
      t.string :phone_number
      t.string :pronoun
      t.text :notes
      
      t.timestamps
    end
    
    add_index :speakers, :email
    add_index :speakers, [:user_id, :name]
  end
end
