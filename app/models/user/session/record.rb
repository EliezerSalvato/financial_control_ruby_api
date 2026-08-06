module User::Session
  class Record < ApplicationRecord
    self.table_name = "user_sessions"

    belongs_to :user, class_name: "User::Record"

    scope :active, -> { where(refresh_token_expires_at: Time.current..) }
  end
end
