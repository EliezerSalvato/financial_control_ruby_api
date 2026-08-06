class User::Password::Reset::Record < ApplicationRecord
  self.table_name = "user_password_resets"

  belongs_to :user, class_name: "User::Record"

  scope :not_reset, -> { where(reset_at: nil) }
  scope :not_expired, -> { where(expires_at: Time.current..) }
  scope :pending, -> { not_reset.not_expired }
end
