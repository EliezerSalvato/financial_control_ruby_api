module Core::User::Session::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def create(user:, user_agent:, ip_address:, refresh_token:, remember_me:, token_adapter: User::Adapters.token, **)
      user => Core::User::Entity
      user_agent => String | nil
      ip_address => String | nil
      refresh_token => String
      remember_me => true | false
      token_adapter => Core::User::Token::Interface

      super.tap do
        _1 => (
          Solid::Failure(:session_creation_failed, { session: Core::User::Session::Entity, errors: Core::Errors }) |
          Solid::Success(:session_created, { session: Core::User::Session::Entity })
        )
      end
    end

    def revoke_all_by(user_id:, **)
      UUID.valid?(user_id) => true

      super.tap do
        _1 => (Solid::Failure(:sessions_revocation_failed, {}) | Solid::Success(:sessions_revoked, {}))
      end
    end

    def find_by_refresh_token(refresh_token:, token_adapter: User::Adapters.token, **)
      refresh_token => String
      token_adapter => Core::User::Token::Interface

      super.tap do
        _1 => (
          Solid::Failure(:invalid_refresh_token, {}) |
          Solid::Success(:session_found, { session: Core::User::Session::Entity, user: Core::User::Entity })
        )
      end
    end

    def update_refresh_token(session:, refresh_token:, remember_me:, token_adapter: User::Adapters.token, **)
      session => Core::User::Session::Entity
      refresh_token => String
      remember_me => true | false
      token_adapter => Core::User::Token::Interface

      super.tap do
        _1 => (
          Solid::Failure(:refresh_token_update_failed, { session: Core::User::Session::Entity, errors: Core::Errors }) |
          Solid::Success(:refresh_token_updated, { session: Core::User::Session::Entity })
        )
      end
    end
  end
end
