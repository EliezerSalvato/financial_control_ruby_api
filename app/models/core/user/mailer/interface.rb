module Core::User::Mailer::Interface
  include Solid::Adapters::Interface

  module Methods
    def deliver_confirmation(email:, token:)
      email => String
      token => String
      super
    end

    def deliver_password_reset(email:, token:)
      email => String
      token => String
      super
    end
  end
end
