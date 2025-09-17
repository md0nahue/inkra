class InterviewPreset < ApplicationRecord
  has_many :preset_questions, dependent: :destroy
  has_many :projects
  has_many :user_shown_interview_presets, dependent: :destroy
  
  scope :active, -> { where(active: true) }
  scope :featured, -> { where(is_featured: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :ordered, -> { order(:order_position, :title) }
  
  validates :title, presence: true
  validates :description, presence: true
  validates :category, presence: true
  validates :icon_name, presence: true
  validates :uuid, presence: true, uniqueness: true
  
  def to_param
    uuid
  end
  
  def questions_grouped_by_chapter
    preset_questions.includes(:interview_preset)
      .order(:chapter_order, :section_order, :question_order)
      .group_by(&:chapter_title)
  end
  
  def total_questions_count
    preset_questions.count
  end
  
  def shown_to_user?(user)
    return false unless user
    user_shown_interview_presets.exists?(user: user)
  end
  
  def mark_as_shown_to_user(user)
    return unless user
    user_shown_interview_presets.find_or_create_by(user: user) do |record|
      record.shown_at = Time.current
    end
  end
end