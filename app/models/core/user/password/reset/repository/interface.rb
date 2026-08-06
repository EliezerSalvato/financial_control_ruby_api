module Core::User::Password::Reset::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def create(user:, token_adapter: User::Adapters.token, **)
      user => Core::User::Entity
      token_adapter => Core::User::Token::Interface
      super.tap do
        _1 => (
          Solid::Failure(:password_reset_creation_failed, { password_reset: Core::User::Password::Reset::Entity, errors: Core::Errors }) |
          Solid::Success(:password_reset_created, { password_reset: Core::User::Password::Reset::Entity, token: String })
        )
      end
    end

    def invalidate_all_by(user_id:, **)
      UUID.valid?(user_id) => true

      super.tap do
        _1 => (
          Solid::Failure(:password_resets_invalidation_failed, {}) |
          Solid::Success(:password_resets_invalidated, {})
        )
      end
    end

    def find_by_token(token:, token_adapter: User::Adapters.token, **)
      token => String
      token_adapter => Core::User::Token::Interface

      super.tap do
        _1 => (
          Solid::Failure(:password_reset_not_found, {}) |
          Solid::Success(:password_reset_found, { password_reset: Core::User::Password::Reset::Entity })
        )
      end
    end

    def mark_as_reset(password_reset:)
      password_reset => Core::User::Password::Reset::Entity

      super.tap do
        _1 => (
          Solid::Failure(:mark_password_reset_as_reset_failed, {}) |
          Solid::Success(:password_reset_marked_as_reset, { password_reset: Core::User::Password::Reset::Entity })
        )
      end
    end
  end
end
