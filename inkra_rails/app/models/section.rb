class Section < ApplicationRecord
  belongs_to :chapter
  has_many :questions, dependent: :destroy

  validates :title, presence: true
  validates :order, presence: true, uniqueness: { scope: :chapter_id }
  validates :omitted, inclusion: { in: [true, false] }

  scope :included, -> { where(omitted: false) }
  scope :by_order, -> { order(:order) }
end
