class OperatorUser < ApplicationRecord
  has_secure_password

  has_many :human_reviews, dependent: :nullify

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  before_save { self.email = email.downcase }
end
