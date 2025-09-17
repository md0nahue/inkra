class PresetQuestion < ApplicationRecord
  belongs_to :interview_preset
  
  scope :ordered, -> { order(:chapter_order, :section_order, :question_order) }
  scope :by_chapter, ->(chapter_title) { where(chapter_title: chapter_title) }
  scope :by_section, ->(section_title) { where(section_title: section_title) }
  
  validates :chapter_title, presence: true
  validates :section_title, presence: true
  validates :question_text, presence: true
  validates :chapter_order, presence: true, numericality: { greater_than: 0 }
  validates :section_order, presence: true, numericality: { greater_than: 0 }
  validates :question_order, presence: true, numericality: { greater_than: 0 }
  
  def chapter_and_section
    "#{chapter_title} - #{section_title}"
  end
  
  def full_order_key
    [chapter_order, section_order, question_order]
  end
end