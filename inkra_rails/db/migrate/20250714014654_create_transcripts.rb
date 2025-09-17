class CreateTranscripts < ActiveRecord::Migration[7.1]
  def change
    create_table :transcripts do |t|
      t.references :project, null: false, foreign_key: true
      t.string :status
      t.text :content
      t.datetime :last_updated

      t.timestamps
    end
  end
end
