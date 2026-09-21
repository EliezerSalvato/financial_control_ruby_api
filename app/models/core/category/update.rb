class Core::Category::Update < ApplicationSolidProcess
  deps do
    attribute :category_repository, default: -> { Category::Adapters.repository }

    validates :category_repository, kind_of: Core::Category::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string
    attribute :name, :string
    attribute :color, :string
    attribute :active, :boolean
    attribute :goal_starts_on, :date
    attribute :goal_value, :decimal
    attribute :goal_ends_on, :date

    normalizes :name, with: ->(value) { value&.strip }
    normalizes :color, with: ->(value) { value&.strip }

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :name, presence: true, allow_nil: true
    validates :color, presence: true, format: { with: Core::Color::FORMAT }, allow_nil: true
    validates :goal_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end


  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:find_category)
        .and_then(:check_if_name_is_taken)
        .and_then(:ensure_goal_months_are_open)
        .and_then(:update_goal)
        .and_then(:update_category)
        .and_then(:reload_category)
    }
  end

  private

  def find_category(user:, id:, **)
    case deps.category_repository.find_by_id(user:, id:)
    in Solid::Success(category:) then Continue(category:)
    in Solid::Failure(type: :category_not_found)
      Failure(:category_not_found)
    end
  end

  def check_if_name_is_taken(user:, name:, category:, **)
    return Continue() if name.nil?

    input.errors.add(:name, :taken) if deps.category_repository.exists?(user:, name:, excluding_id: category.id)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def ensure_goal_months_are_open(user:, category:, goal_starts_on:, goal_ends_on:, **)
    if category.goals.empty? && goal_starts_on.present?
      result = with_nested_process(Core::MonthlyStatus::EnsureOpen.call(user:, date: goal_starts_on))
      return result unless result.success?
    end

    return Continue() if goal_ends_on.blank?
    return Continue() if goal_starts_on.present? && same_month?(goal_starts_on, goal_ends_on)

    with_nested_process(Core::MonthlyStatus::EnsureOpen.call(user:, date: goal_ends_on))
  end

  def update_goal(category:, goal_starts_on:, goal_value:, goal_ends_on:, **)
    with_nested_process(
      Core::Category::Goal::Update.call(category:, goal_starts_on:, goal_value:, goal_ends_on:),
      persist_failure: :category_update_failed
    )
  end

  def update_category(category:, name:, color:, active:, goal_ends_on:, **)
    attributes = { name:, color:, active:, goal_ends_on: goal_ends_on&.beginning_of_month }.compact

    case deps.category_repository.update(category:, attributes:)
    in Solid::Success(category:) then Continue(category:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :category_update_failed)

      Failure(:category_update_failed, input:)
    end
  end

  def reload_category(user:, category:, **)
    case deps.category_repository.find_by_id(user:, id: category.id)
    in Solid::Success(category:) then Continue(category:)
    in Solid::Failure
      input.errors.add(:base, :category_update_failed)
      Failure(:category_update_failed, input:)
    end
  end

  def same_month?(left, right)
    left.month == right.month && left.year == right.year
  end
end
