class Core::Category::Goal::Update < ApplicationSolidProcess
  deps do
    attribute :goal_repository, default: -> { Category::Adapters.goal_repository }

    validates :goal_repository, kind_of: Core::Category::Goal::Repository::Interface
  end

  input do
    attribute :category
    attribute :goal_starts_on, :date
    attribute :goal_value, :decimal
    attribute :goal_ends_on, :date

    validates :category, presence: true
    validates :category, kind_of: Core::Category::Entity
    validates :goal_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:reject_value_change_when_goal_exists)
      .and_then(:validate_goal_pair)
      .and_then(:validate_goal_window)
      .and_then(:create_first_goal)
  end

  private

  def reject_value_change_when_goal_exists(category:, goal_starts_on:, goal_value:, **)
    return Continue() if category.goals.empty?
    return Continue() if goal_starts_on.nil? && goal_value.nil?

    input.errors.add(:goal_starts_on, :cannot_be_changed) if goal_starts_on.present?
    input.errors.add(:goal_value, :cannot_be_changed) unless goal_value.nil?

    Failure(:invalid_input, input:)
  end

  def validate_goal_pair(category:, goal_starts_on:, goal_value:, goal_ends_on:, **)
    return Continue() if category.goals.any?
    return Continue() if goal_starts_on.nil? && goal_value.nil? && goal_ends_on.nil?

    input.errors.add(:goal_starts_on, :blank) if goal_starts_on.blank?
    input.errors.add(:goal_value, :blank) if goal_value.nil?

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def validate_goal_window(category:, goal_starts_on:, goal_ends_on:, **)
    return Continue() if goal_ends_on.blank?

    starts_on_for_window = goal_starts_on || category.goals.map(&:starts_on).compact.max
    return Continue() if starts_on_for_window.blank?

    ends_on_month = goal_ends_on.beginning_of_month
    starts_on_month = starts_on_for_window.beginning_of_month

    if goal_starts_on.present?
      if ends_on_month < starts_on_month
        input.errors.add(:goal_ends_on, :before_starts_on)
        return Failure(:invalid_input, input:)
      end
    elsif ends_on_month <= starts_on_month
      input.errors.add(:goal_ends_on, :before_existing_goal)
      return Failure(:invalid_input, input:)
    end

    Continue()
  end

  def create_first_goal(category:, goal_starts_on:, goal_value:, **)
    return Continue() if category.goals.any?
    return Continue() if goal_starts_on.blank? || goal_value.nil?

    case deps.goal_repository.create(category:, starts_on: goal_starts_on, value: goal_value)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:goal_creation_failed, errors:)
    end
  end
end
