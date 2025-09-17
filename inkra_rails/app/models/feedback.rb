class Feedback < ApplicationRecord
  belongs_to :user
  
  validates :feedback_text, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :feedback_type, inclusion: { in: %w[general bug_report feature_request improvement] }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  
  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :by_type, ->(type) { where(feedback_type: type) }
  scope :recent, -> { order(created_at: :desc) }
  
  def mark_resolved!(admin_notes = nil)
    update!(resolved: true, admin_notes: admin_notes)
  end
  
  def mark_unresolved!
    update!(resolved: false, admin_notes: nil)
  end
end