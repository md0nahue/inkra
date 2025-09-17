class Transcript < ApplicationRecord
  belongs_to :project

  enum status: { processing_raw: 'processing_raw', raw_ready: 'raw_ready', editing: 'editing', ready: 'ready', failed: 'failed' }
  validates :status, presence: true

  before_update :update_timestamp

  # Legacy JSON methods for backwards compatibility
  def edited_content_json
    JSON.parse(edited_content) if edited_content.present?
  rescue JSON::ParserError
    []
  end

  def edited_content_json=(value)
    self.edited_content = value.to_json
  end

  def raw_structured_content_json
    JSON.parse(raw_structured_content) if raw_structured_content.present?
  rescue JSON::ParserError
    []
  end

  def raw_structured_content_json=(value)
    self.raw_structured_content = value.to_json
  end

  # New simplified content methods
  def raw_transcript
    raw_content
  end

  def polished_transcript
    polished_content
  end

  private

  def update_timestamp
    self.last_updated = Time.current
  end
end
