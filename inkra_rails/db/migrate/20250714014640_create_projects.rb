class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.string :title
      t.string :status
      t.text :topic
      t.datetime :last_modified_at

      t.timestamps
    end
  end
end
