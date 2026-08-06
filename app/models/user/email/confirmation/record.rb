class User::Email::Confirmation::Record < ApplicationRecord
  self.table_name = "user_email_confirmations"

  belongs_to :user, class_name: "User::Record"

  scope :not_confirmed, -> { where(confirmed_at: nil) }
  scope :not_expired, -> { where(expires_at: Time.current..) }
  scope :pending, -> { not_confirmed.not_expired }
end
