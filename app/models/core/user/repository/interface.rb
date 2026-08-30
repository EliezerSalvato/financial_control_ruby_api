module Core::User::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def create(first_name:, last_name:, email:, password:, password_confirmation:)
      first_name => String
      last_name => String
      email => String
      password => String
      password_confirmation => String

      super.tap do
        _1 => (
          Solid::Failure(:user_creation_failed, { user: Core::User::Entity, errors: Core::Errors }) |
          Solid::Success(:user_created, { user: Core::User::Entity })
        )
      end
    end

    def exists?(email:)
      email => String

      super.tap do
        _1 => (true | false)
      end
    end

    def verified?(user:)
      user => Core::User::Entity

      super.tap do
        _1 => (true | false)
      end
    end

    def active?(user:)
      user => Core::User::Entity

      super.tap do
        _1 => (true | false)
      end
    end

    def find_by_email_and_password(email:, password:)
      email => String
      password => String

      super.tap do
        _1 => (
          Solid::Failure(:invalid_email_or_password, {}) |
          Solid::Success(:user_found, { user: Core::User::Entity })
        )
      end
    end

    def find_by_confirmation_token(token:, token_adapter: User::Adapters.token, **)
      token => String
      token_adapter => Core::User::Token::Interface

      super.tap do
        _1 => (
          Solid::Failure(:invalid_token, {}) |
          Solid::Success(:user_found, { user: Core::User::Entity })
        )
      end
    end

    def find_by_email(email:)
      email => String

      super.tap do
        _1 => (
          Solid::Failure(:user_not_found, {}) |
          Solid::Success(:user_found, { user: Core::User::Entity })
        )
      end
    end

    def find_by_id(id:)
      id => String

      super.tap do
        _1 => (
          Solid::Failure(:user_not_found, {}) |
          Solid::Success(:user_found, { user: Core::User::Entity })
        )
      end
    end

    def find_by_reset_password_token(token:, token_adapter: User::Adapters.token, **)
      token => String
      token_adapter => Core::User::Token::Interface

      super.tap do
        _1 => (
          Solid::Failure(:invalid_token, {}) |
          Solid::Success(:user_found, { user: Core::User::Entity })
        )
      end
    end

    def mark_as_verified(user:)
      user => Core::User::Entity

      super.tap do
        _1 => (
          Solid::Failure(:mark_user_as_verified_failed, {}) |
          Solid::Success(:user_verified, { user: Core::User::Entity })
        )
      end
    end

    def change_email_and_mark_as_not_verified(user:, new_email:)
      user => Core::User::Entity
      new_email => String

      super.tap do
        _1 => (
          Solid::Failure(:change_email_and_mark_as_not_verified_failed, {}) |
          Solid::Success(:user_email_changed, { user: Core::User::Entity })
        )
      end
    end

    def authenticate(user:, password:)
      user => Core::User::Entity
      password => String

      super.tap do
        _1 => (
          Solid::Failure(:current_password_is_invalid, {}) |
          Solid::Success(:authenticated, { user: Core::User::Entity })
        )
      end
    end

    def update_password(user:, password:, password_confirmation:)
      user => Core::User::Entity
      password => String
      password_confirmation => String

      super.tap do
        _1 => (
          Solid::Failure(:password_update_failed, { user: Core::User::Entity, errors: Core::Errors }) |
          Solid::Success(:password_updated, { user: Core::User::Entity })
        )
      end
    end

    def update_profile(user:, first_name:, last_name:)
      user => Core::User::Entity
      first_name => String
      last_name => String

      super.tap do
        _1 => (
          Solid::Failure(:profile_update_failed, { user: Core::User::Entity, errors: Core::Errors }) |
          Solid::Success(:profile_updated, { user: Core::User::Entity })
        )
      end
    end

    def destroy(user:)
      user => Core::User::Entity

      super.tap do
        _1 => (
          Solid::Failure(:user_destruction_failed, {}) |
          Solid::Success(:user_destroyed, {})
        )
      end
    end
  end
end
