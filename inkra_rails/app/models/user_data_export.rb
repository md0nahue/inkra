class UserDataExport < ApplicationRecord
  belongs_to :user
  
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed expired] }
  validates :file_count, numericality: { greater_than_or_equal_to: 0 }
  validates :total_size_bytes, numericality: { greater_than_or_equal_to: 0 }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: 'completed') }
  scope :valid_exports, -> { where(status: 'completed').where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :for_cleanup, -> { where(status: ['completed', 'failed']).where('created_at < ?', 1.month.ago) }
  
  before_create :set_expiration_date
  
  # Weekly throttling - only allow one export per week per user
  def self.can_create_new_export?(user)
    last_export = where(user: user).recent.first
    return true if last_export.nil?
    
    # Allow new export if last one was more than 7 days ago
    last_export.created_at < 7.days.ago
  end
  
  def expired?
    expires_at && expires_at < Time.current
  end
  
  def completed?
    status == 'completed'
  end
  
  def processing?
    status == 'processing'
  end
  
  def failed?
    status == 'failed'
  end
  
  def ready_for_download?
    completed? && !expired? && s3_key.present?
  end
  
  # Check if user's data has changed since this export
  def data_is_stale?
    return true unless completed?
    
    current_highest_project_id = user.projects.maximum(:id) || 0
    current_highest_audio_segment_id = user.audio_segments.joins(:project).maximum(:id) || 0
    
    (current_highest_project_id > (highest_project_id || 0)) ||
    (current_highest_audio_segment_id > (highest_audio_segment_id || 0))
  end
  
  def formatted_file_size
    return "Unknown" if total_size_bytes.zero?
    
    units = %w[bytes KB MB GB TB]
    base = 1024
    size = total_size_bytes.to_f
    
    if size < base
      return "#{size.to_i} bytes"
    end
    
    exp = (Math.log(size) / Math.log(base)).to_i
    exp = [exp, units.length - 1].min
    
    "%.1f %s" % [size / (base ** exp), units[exp]]
  end
  
  def days_until_expiration
    return 0 if expired?
    ((expires_at - Time.current) / 1.day).ceil
  end
  
  private
  
  def set_expiration_date
    self.expires_at = 7.days.from_now
  end
end
