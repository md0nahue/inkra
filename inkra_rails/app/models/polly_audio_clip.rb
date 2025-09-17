class PollyAudioClip < ApplicationRecord
  belongs_to :question
  
  validates :s3_key, presence: true, uniqueness: true, if: :completed?
  validates :voice_id, presence: true
  validates :status, inclusion: { in: %w[pending generating completed failed] }
  validates :speech_rate, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 500 }
  
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :pending, -> { where(status: 'pending') }
  scope :generating, -> { where(status: 'generating') }
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def generating?
    status == 'generating'
  end
  
  def pending?
    status == 'pending'
  end
  
  def s3_url
    return nil unless completed? && s3_key.present?
    
    presigned_url = S3Service.new(question.project.user).get_presigned_url(s3_key)
    
    # DEBUG: Log URL generation
    Rails.logger.debug "\n🔗📝 S3 URL GENERATION"
    Rails.logger.debug "🆔 Question ID: #{question.id}"
    Rails.logger.debug "📝 Question Text: \"#{question.text[0..50]}...\""
    Rails.logger.debug "🗝 S3 Key: #{s3_key}"
    Rails.logger.debug "🎙️ Voice: #{voice_id}"
    Rails.logger.debug "⏱️ Rate: #{speech_rate}"
    Rails.logger.debug "🔗 Generated URL: #{presigned_url[0..100]}...\n"
    
    presigned_url
  end
  
  def needs_regeneration?(new_voice_id, new_speech_rate)
    completed? && (voice_id != new_voice_id || speech_rate != new_speech_rate)
  end
  
  def mark_as_generating!
    update!(status: 'generating', error_message: nil)
  end
  
  def mark_as_completed!(s3_key, content_type: nil, request_characters: nil)
    update!(
      status: 'completed',
      s3_key: s3_key,
      content_type: content_type,
      request_characters: request_characters,
      error_message: nil
    )
  end
  
  def mark_as_failed!(error_message)
    update!(
      status: 'failed',
      error_message: error_message.to_s.truncate(500),
      s3_key: nil
    )
  end
end