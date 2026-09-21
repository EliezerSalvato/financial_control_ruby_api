class Core::Category::Goal::Creation < ApplicationSolidProcess
  deps do
    attribute :goal_repository, default: -> { Category::Adapters.goal_repository }

    validates :goal_repository, kind_of: Core::Category::Goal::Repository::Interface
  end

  input do
    attribute :category
    attribute :starts_on, :date
    attribute :value, :decimal

    validates :starts_on, :value, presence: true
    validates :category, kind_of: Core::Category::Entity
    validates :value, numericality: { greater_than_or_equal_to: 0 }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:create_goal)
  end

  private

  def create_goal(category:, starts_on:, value:, **)
    case deps.goal_repository.create(category:, starts_on:, value:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:goal_creation_failed, errors:)
    end
  end
end
