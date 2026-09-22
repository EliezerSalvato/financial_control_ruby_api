module Goal::Repository::Adapters::ActiveRecord
  include Core::Goal::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list(user_id:, month:, year:)
    records = Goal::Record.for_period(user_id:, month:, year:)

    Success(:goal_transactions_listed, goal_transactions: Goal::Mapper.to_entities(records))
  end

  def list_targets(user_id:, month:, year:)
    records = Goal::Target::Record.for_period(user_id:, month:, year:)

    Success(:goal_targets_listed, goal_targets: Goal::Target::Mapper.to_entities(records))
  end
end
