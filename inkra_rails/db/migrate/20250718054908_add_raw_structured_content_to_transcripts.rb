class AddRawStructuredContentToTranscripts < ActiveRecord::Migration[7.1]
  def change
    add_column :transcripts, :raw_structured_content, :text
  end
end
