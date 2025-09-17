class Tracker < ApplicationRecord
  belongs_to :user
  has_many :log_entries, dependent: :destroy
  
  validates :name, presence: true
  validates :sf_symbol_name, presence: true
  validates :color_hex, presence: true, format: { with: /\A#[0-9A-F]{6}\z/i }
  
  scope :recently_accessed, -> { where.not(last_accessed_at: nil).order(last_accessed_at: :desc) }
  
  def touch_accessed
    update_column(:last_accessed_at, Time.current)
  end
end
