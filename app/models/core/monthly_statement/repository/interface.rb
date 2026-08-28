module Core::MonthlyStatement::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def list(user_id:, month:, year:, statuses: nil, on: nil)
      user_id => String
      month => Integer
      year => Integer
      statuses => Array | NilClass
      on => Date | NilClass

      super.tap do
        _1 => Solid::Success(:monthly_statements_listed, { monthly_statements: Array })
      end
    end

    def list_transfers(user_id:, month:, year:, statuses: nil, on: nil)
      user_id => String
      month => Integer
      year => Integer
      statuses => Array | NilClass
      on => Date | NilClass

      super.tap do
        _1 => Solid::Success(:monthly_statement_transfers_listed, { monthly_statement_transfers: Array })
      end
    end
  end
end
