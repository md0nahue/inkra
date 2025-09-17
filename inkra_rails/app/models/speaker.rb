class Speaker < ApplicationRecord
  belongs_to :user
  
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone_number, format: { with: /\A\+?[0-9\s\-\(\)]+\z/ }, allow_blank: true
  validates :pronoun, inclusion: { in: %w[he she they] }, allow_blank: true
  
  validate :has_contact_method
  
  private
  
  def has_contact_method
    if email.blank? && phone_number.blank?
      errors.add(:base, "Must have either email or phone number")
    end
  end
end