module Core::User::Token::Interface
  include Solid::Adapters::Interface

  module Methods
    def generate
      super.tap { _1 => String }
    end

    def digest(token)
      token => String

      super.tap { _1 => String }
    end

    def generate_for(user:, purpose:)
      user => Core::User::Entity
      purpose => Symbol

      super.tap { _1 => String }
    end

    def find_by(purpose:, token:)
      purpose => Symbol
      token => String

      super.tap { _1 => (Core::User::Entity | nil) }
    end

    def sign(user:, purpose:, expires_in:)
      user => Core::User::Entity
      purpose => Symbol
      expires_in => ActiveSupport::Duration

      super.tap { _1 => String }
    end
  end
end
