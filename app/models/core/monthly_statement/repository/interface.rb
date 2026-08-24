module Core::MonthlyStatement::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def list(user:, month:, year:)
      user => Core::User::Entity
      month => Integer
      year => Integer

      super.tap do
        _1 => Solid::Success(:monthly_statements_listed, { monthly_statements: Array })
      end
    end
  end
end
