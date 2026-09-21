class Core::Category::Creation < ApplicationSolidProcess
  deps do
    attribute :category_repository, default: -> { Category::Adapters.repository }

    validates :category_repository, kind_of: Core::Category::Repository::Interface
  end

  input do
    attribute :user
    attribute :name, :string
    attribute :color, :string
    attribute :active, :boolean, default: true
    attribute :goal_starts_on, :date
    attribute :goal_value, :decimal
    attribute :goal_ends_on, :date

    normalizes :name, with: ->(value) { value.strip }
    normalizes :color, with: ->(value) { value.strip }

    validates :user, :name, :color, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :color, format: { with: Core::Color::FORMAT }
    validates :goal_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end


  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:check_if_name_is_taken)
        .and_then(:validate_goal_pair)
        .and_then(:validate_goal_window)
        .and_then(:ensure_goal_months_are_open)
        .and_then(:create_category)
        .and_then(:create_goal)
        .and_then(:reload_category)
    }
  end

  private

  def check_if_name_is_taken(user:, name:, **)
    input.errors.add(:name, :taken) if deps.category_repository.exists?(user:, name:)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def validate_goal_pair(goal_starts_on:, goal_value:, goal_ends_on:, **)
    return Continue() if goal_starts_on.nil? && goal_value.nil? && goal_ends_on.nil?

    input.errors.add(:goal_starts_on, :blank) if goal_starts_on.blank?
    input.errors.add(:goal_value, :blank) if goal_value.nil?

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def validate_goal_window(goal_starts_on:, goal_ends_on:, **)
    return Continue() if goal_starts_on.blank? || goal_ends_on.blank?
    return Continue() if goal_starts_on.beginning_of_month <= goal_ends_on.beginning_of_month

    input.errors.add(:goal_ends_on, :before_starts_on)
    Failure(:invalid_input, input:)
  end

  def ensure_goal_months_are_open(user:, goal_starts_on:, goal_ends_on:, **)
    return Continue() if goal_starts_on.blank?

    result = with_nested_process(Core::MonthlyStatus::EnsureOpen.call(user:, date: goal_starts_on))
    return result unless result.success?
    return Continue() if goal_ends_on.blank? || same_month?(goal_starts_on, goal_ends_on)

    with_nested_process(Core::MonthlyStatus::EnsureOpen.call(user:, date: goal_ends_on))
  end

  def create_category(user:, name:, color:, active:, goal_ends_on:, **)
    case deps.category_repository.create(user:, attributes: { name:, color:, active:, goal_ends_on: goal_ends_on&.beginning_of_month }.compact)

    in Solid::Success(category:) then Continue(category:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :category_creation_failed)

      Failure(:category_creation_failed, input:)
    end
  end

  def create_goal(category:, goal_starts_on:, goal_value:, **)
    return Continue() if goal_starts_on.blank? || goal_value.nil?

    with_nested_process(
      Core::Category::Goal::Creation.call(category:, starts_on: goal_starts_on, value: goal_value),
      persist_failure: :category_creation_failed
    )
  end

  def reload_category(user:, category:, **)
    case deps.category_repository.find_by_id(user:, id: category.id)
    in Solid::Success(category:) then Continue(category:)
    in Solid::Failure
      input.errors.add(:base, :category_creation_failed)
      Failure(:category_creation_failed, input:)
    end
  end

  def same_month?(left, right)
    left.month == right.month && left.year == right.year
  end
end
