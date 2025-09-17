class Chapter < ApplicationRecord
  belongs_to :project
  has_many :sections, dependent: :destroy
  has_many :questions, through: :sections

  validates :title, presence: true
  validates :order, presence: true, uniqueness: { scope: :project_id }
  validates :omitted, inclusion: { in: [true, false] }

  scope :included, -> { where(omitted: false) }
  scope :by_order, -> { order(:order) }
end
