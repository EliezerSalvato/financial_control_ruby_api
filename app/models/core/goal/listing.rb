class Core::Goal::Listing < ApplicationSolidProcess
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
      .and_then(:list_goal_transactions)
  end

  private

  def list_goal_transactions(user:, month:, year:, **)
    case deps.goal_repository.list(user_id: user.id, month:, year:)
    in Solid::Success(goal_transactions:)
      Continue(goal_transactions:)
    end
  end
end
