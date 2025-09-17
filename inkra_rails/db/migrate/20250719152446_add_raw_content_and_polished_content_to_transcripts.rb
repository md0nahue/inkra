class AddRawContentAndPolishedContentToTranscripts < ActiveRecord::Migration[7.1]
  def change
    add_column :transcripts, :raw_content, :text
    add_column :transcripts, :polished_content, :text
  end
end
