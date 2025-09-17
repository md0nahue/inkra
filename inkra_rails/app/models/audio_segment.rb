class AudioSegment < ApplicationRecord
  belongs_to :project
  belongs_to :question, optional: true

  validates :file_name, presence: true
  validates :mime_type, presence: true
  validates :upload_status, presence: true, inclusion: { in: %w[pending uploading success failed transcribed transcription_failed] }
  validates :duration_seconds, presence: true, numericality: { greater_than: 0 }

  scope :successful, -> { where(upload_status: 'success') }
  scope :by_question, ->(question_id) { where(question_id: question_id) }

  def uploaded?
    upload_status == 'success'
  end

  def transcribed?
    upload_status == 'transcribed'
  end

  def failed?
    %w[failed transcription_failed].include?(upload_status)
  end

  def processing?
    %w[pending uploading].include?(upload_status)
  end

  def has_transcription?
    transcription_text.present?
  end

  def estimated_transcription_time
    return 60 if duration_seconds.nil? # default fallback
    (duration_seconds * 0.25).to_i # 25% of audio duration
  end
end
