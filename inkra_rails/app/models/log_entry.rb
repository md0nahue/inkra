class LogEntry < ApplicationRecord
  belongs_to :user
  belongs_to :tracker
  
  validates :timestamp_utc, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending uploading transcribing completed failed] }
  
  scope :by_tracker, ->(tracker_ids) { where(tracker_id: tracker_ids) if tracker_ids.present? }
  scope :by_date_range, ->(start_date, end_date) {
    where(timestamp_utc: start_date..end_date) if start_date.present? && end_date.present?
  }
end
