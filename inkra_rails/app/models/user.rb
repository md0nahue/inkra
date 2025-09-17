class User < ApplicationRecord
  has_secure_password
  has_many :projects, dependent: :destroy
  has_many :trackers, dependent: :destroy
  has_many :log_entries, dependent: :destroy
  has_many :feedbacks, dependent: :destroy
  has_many :device_logs, dependent: :destroy
  
  has_many :speakers, dependent: :destroy
  has_many :user_shown_interview_presets, dependent: :destroy
  has_many :user_data_exports, dependent: :destroy

  INTEREST_CATEGORIES = %w[
    fiction_writing
    non_fiction_writing
    personal_growth
    mental_health
    social_sharing
    health_fitness
  ].freeze

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }
  validate :interests_are_valid


  def admin?
    admin == true
  end

  private

  def interests_are_valid
    if interests.any? { |interest| !INTEREST_CATEGORIES.include?(interest) }
      errors.add(:interests, "contains an invalid category")
    end
  end
end
