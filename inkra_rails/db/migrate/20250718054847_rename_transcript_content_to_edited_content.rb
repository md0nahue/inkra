class RenameTranscriptContentToEditedContent < ActiveRecord::Migration[7.1]
  def change
    rename_column :transcripts, :content, :edited_content
  end
end
