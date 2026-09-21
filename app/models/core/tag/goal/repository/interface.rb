module Core::Tag::Goal::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def create(tag:, starts_on:, value:)
      tag => Core::Tag::Entity
      starts_on => Date
      value => Numeric

      super.tap do
        _1 => (
          Solid::Failure(:goal_creation_failed, { errors: Core::Errors }) |
          Solid::Success(:goal_created, { goal: Core::Tag::Goal::Entity })
        )
      end
    end

    def find_by_starts_on(tag:, starts_on:)
      tag => Core::Tag::Entity
      starts_on => Date

      super.tap do
        _1 => (
          Solid::Failure(:goal_not_found, {}) |
          Solid::Success(:goal_found, { goal: Core::Tag::Goal::Entity })
        )
      end
    end

    def find_latest(tag:)
      tag => Core::Tag::Entity

      super.tap do
        _1 => (
          Solid::Failure(:goal_not_found, {}) |
          Solid::Success(:goal_found, { goal: Core::Tag::Goal::Entity })
        )
      end
    end

    def update(goal:, attributes:)
      goal => Core::Tag::Goal::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:goal_update_failed, { errors: Core::Errors }) |
          Solid::Success(:goal_updated, { goal: Core::Tag::Goal::Entity })
        )
      end
    end

    def destroy_after(tag:, starts_on:)
      tag => Core::Tag::Entity
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
