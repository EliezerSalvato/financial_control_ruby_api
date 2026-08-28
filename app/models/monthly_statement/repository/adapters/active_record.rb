module MonthlyStatement::Repository::Adapters::ActiveRecord
  include Core::MonthlyStatement::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list(user_id:, month:, year:, statuses: nil, on: nil)
    records = MonthlyStatement::Record.for_period(user_id:, month:, year:, statuses:, on:)

    Success(:monthly_statements_listed, monthly_statements: MonthlyStatement::Mapper.to_entities(records))
  end

  def list_transfers(user_id:, month:, year:, statuses: nil, on: nil)
    records = MonthlyStatement::Transfer::Record.for_period(user_id:, month:, year:, statuses:, on:)

    Success(:monthly_statement_transfers_listed, monthly_statement_transfers: MonthlyStatement::Transfer::Mapper.to_entities(records))
  end
end
