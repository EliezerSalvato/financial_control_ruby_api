module Core::Transaction::Recurrence::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def create(transaction:, starts_on:, value:)
      transaction => Core::Transaction::Entity
      starts_on => Date
      value => Numeric

      super.tap do
        _1 => (
          Solid::Failure(:recurrence_creation_failed, { errors: Core::Errors }) |
          Solid::Success(:recurrence_created, { recurrence: Core::Transaction::Recurrence::Entity })
        )
      end
    end

    def find_by_starts_on(transaction:, starts_on:)
      transaction => Core::Transaction::Entity
      starts_on => Date

      super.tap do
        _1 => (
          Solid::Failure(:recurrence_not_found, {}) |
          Solid::Success(:recurrence_found, { recurrence: Core::Transaction::Recurrence::Entity })
        )
      end
    end

    def find_latest(transaction:)
      transaction => Core::Transaction::Entity

      super.tap do
        _1 => (
          Solid::Failure(:recurrence_not_found, {}) |
          Solid::Success(:recurrence_found, { recurrence: Core::Transaction::Recurrence::Entity })
        )
      end
    end

    def update(recurrence:, attributes:)
      recurrence => Core::Transaction::Recurrence::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:recurrence_update_failed, { errors: Core::Errors }) |
          Solid::Success(:recurrence_updated, { recurrence: Core::Transaction::Recurrence::Entity })
        )
      end
    end

    def destroy_after(transaction:, starts_on:)
      transaction => Core::Transaction::Entity
      starts_on => Date

      super.tap do
        _1 => (
          Solid::Failure(:recurrence_destruction_failed, { errors: Core::Errors }) |
          Solid::Success(:recurrences_destroyed, {})
        )
      end
    end
  end
end
