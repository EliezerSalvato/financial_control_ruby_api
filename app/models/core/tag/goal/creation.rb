class Core::Tag::Goal::Creation < ApplicationSolidProcess
  deps do
    attribute :goal_repository, default: -> { Tag::Adapters.goal_repository }

    validates :goal_repository, kind_of: Core::Tag::Goal::Repository::Interface
  end

  input do
    attribute :tag
    attribute :starts_on, :date
    attribute :value, :decimal

    validates :starts_on, :value, presence: true
    validates :tag, kind_of: Core::Tag::Entity
    validates :value, numericality: { greater_than_or_equal_to: 0 }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:create_goal)
  end

  private

  def create_goal(tag:, starts_on:, value:, **)
    case deps.goal_repository.create(tag:, starts_on:, value:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:goal_creation_failed, errors:)
    end
  end
end
