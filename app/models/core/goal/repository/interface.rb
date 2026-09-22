module Core::Goal::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def list(user_id:, month:, year:)
      UUID.valid?(user_id) => true
      month => Integer
      year => Integer

      super.tap do
        _1 => Solid::Success(:goal_transactions_listed, { goal_transactions: Array })
      end
    end

    def list_targets(user_id:, month:, year:)
      UUID.valid?(user_id) => true
      month => Integer
      year => Integer

      super.tap do
        _1 => Solid::Success(:goal_targets_listed, { goal_targets: Array })
      end
    end
  end
end
