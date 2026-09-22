class Core::Goal::Target::Listing < ApplicationSolidProcess
  deps do
    attribute :goal_repository, default: -> { Goal::Adapters.repository }

    validates :goal_repository, kind_of: Core::Goal::Repository::Interface
  end

  input do
    attribute :user
    attribute :month, :integer
    attribute :year, :integer

    validates :user, presence: true, kind_of: Core::User::Entity
    validates :month, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
    validates :year, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 9999 }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:list_goal_targets)
  end

  private

  def list_goal_targets(user:, month:, year:, **)
    case deps.goal_repository.list_targets(user_id: user.id, month:, year:)
    in Solid::Success(goal_targets:)
      Continue(goal_targets:)
    end
  end
end
