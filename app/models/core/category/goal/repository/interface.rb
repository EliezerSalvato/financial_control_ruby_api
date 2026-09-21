module Core::Category::Goal::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def create(category:, starts_on:, value:)
      category => Core::Category::Entity
      starts_on => Date
      value => Numeric

      super.tap do
        _1 => (
          Solid::Failure(:goal_creation_failed, { errors: Core::Errors }) |
          Solid::Success(:goal_created, { goal: Core::Category::Goal::Entity })
        )
      end
    end

    def find_by_starts_on(category:, starts_on:)
      category => Core::Category::Entity
      starts_on => Date

      super.tap do
        _1 => (
          Solid::Failure(:goal_not_found, {}) |
          Solid::Success(:goal_found, { goal: Core::Category::Goal::Entity })
        )
      end
    end

    def find_latest(category:)
      category => Core::Category::Entity

      super.tap do
        _1 => (
          Solid::Failure(:goal_not_found, {}) |
          Solid::Success(:goal_found, { goal: Core::Category::Goal::Entity })
        )
      end
    end

    def update(goal:, attributes:)
      goal => Core::Category::Goal::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:goal_update_failed, { errors: Core::Errors }) |
          Solid::Success(:goal_updated, { goal: Core::Category::Goal::Entity })
        )
      end
    end

    def destroy_after(category:, starts_on:)
      category => Core::Category::Entity
      starts_on => Date

      super.tap do
        _1 => (
          Solid::Failure(:goal_destruction_failed, { errors: Core::Errors }) |
          Solid::Success(:goals_destroyed, {})
        )
      end
    end
  end
end
