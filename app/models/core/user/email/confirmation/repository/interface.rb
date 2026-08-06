module Core::User::Email::Confirmation::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def create(user:, old_email: nil, token_adapter: User::Adapters.token, **)
      user => Core::User::Entity
      old_email => String | nil
      token_adapter => Core::User::Token::Interface

      super.tap do
        _1 => (
          Solid::Failure(:email_confirmation_creation_failed, { email_confirmation: Core::User::Email::Confirmation::Entity, errors: Core::Errors }) |
          Solid::Success(:email_confirmation_created, { email_confirmation: Core::User::Email::Confirmation::Entity, token: String })
        )
      end
    end

    def invalidate_all_by(user_id:, **)
      UUID.valid?(user_id) => true

      super.tap do
        _1 => (
          Solid::Failure(:email_confirmations_invalidation_failed, {}) |
          Solid::Success(:email_confirmations_invalidated, {})
        )
      end
    end

    def find_by_token(token:, token_adapter: User::Adapters.token, **)
      token => String
      token_adapter => Core::User::Token::Interface

      super.tap do
        _1 => (
          Solid::Failure(:email_confirmation_not_found, {}) |
          Solid::Success(:email_confirmation_found, { email_confirmation: Core::User::Email::Confirmation::Entity })
        )
      end
    end

    def mark_as_confirmed(email_confirmation:)
      email_confirmation => Core::User::Email::Confirmation::Entity

      super.tap do
        _1 => (
          Solid::Failure(:mark_email_confirmation_as_confirmed_failed, {}) |
          Solid::Success(:email_confirmation_marked_as_confirmed, { email_confirmation: Core::User::Email::Confirmation::Entity })
        )
      end
    end
  end
end
