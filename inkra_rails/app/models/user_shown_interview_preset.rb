class UserShownInterviewPreset < ApplicationRecord
  belongs_to :user
  belongs_to :interview_preset
  
  scope :recent, -> { order(shown_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :before_date, ->(date) { where('shown_at < ?', date) }
  
  validates :shown_at, presence: true
  validates :user_id, uniqueness: { scope: :interview_preset_id }
  
  def self.clear_old_records(user, days_old = 30)
    for_user(user).before_date(days_old.days.ago).delete_all
  end
  
  def self.reset_for_user(user)
    for_user(user).delete_all
  end
end