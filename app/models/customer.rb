class Customer < ApplicationRecord
  has_many :conversations, dependent: :nullify

  validates :external_id, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
