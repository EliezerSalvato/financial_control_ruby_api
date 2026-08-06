class User::Record < ApplicationRecord
  self.table_name = "users"

  has_paper_trail

  has_many :sessions, class_name: "User::Session::Record", foreign_key: :user_id, dependent: :destroy
  has_many :email_confirmations, class_name: "User::Email::Confirmation::Record", foreign_key: :user_id, dependent: :destroy
  has_many :password_resets, class_name: "User::Password::Reset::Record", foreign_key: :user_id, dependent: :destroy

  has_secure_password

  generates_token_for :reset_password, expires_in: Core::User::Password::RESET_TOKEN_EXPIRES_IN do
    password_salt&.last(10)
  end

  generates_token_for :email_confirmation, expires_in: Core::User::Email::CONFIRMATION_TOKEN_EXPIRES_IN do
    [ email, verified ]
  end
end
