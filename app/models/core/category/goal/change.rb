class Core::Category::Goal::Change < ApplicationSolidProcess
  deps do
    attribute :category_repository, default: -> { Category::Adapters.repository }
    attribute :goal_repository, default: -> { Category::Adapters.goal_repository }
    attribute :monthly_status_repository, default: -> { MonthlyStatus::Adapters.repository }

    validates :category_repository, kind_of: Core::Category::Repository::Interface
    validates :goal_repository, kind_of: Core::Category::Goal::Repository::Interface
    validates :monthly_status_repository, kind_of: Core::MonthlyStatus::Repository::Interface
  end

  input do
    attribute :user
    attribute :category_id, :string
    attribute :starts_on, :date
    attribute :value, :decimal
    attribute :change_for_next_months, :boolean, default: false

    validates :user, :category_id, :starts_on, :value, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :value, numericality: { greater_than_or_equal_to: 0 }
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:find_category)
        .and_then(:ensure_month_is_open)
        .and_then(:validate_starts_on_window)
        .and_then(:resolve_existing_goal)
        .and_then(:reject_same_value)
        .and_then(:upsert_current_month)
        .and_then(:apply_following_months_policy)
        .and_then(:reload_category)
    }
  end

  private

  def find_category(user:, category_id:, **)
    case deps.category_repository.find_by_id(user:, id: category_id)
    in Solid::Success(category:) then Continue(category:)
    in Solid::Failure(type: :category_not_found)
      Failure(:category_not_found)
    end
  end

  def ensure_month_is_open(user:, starts_on:, **)
    with_nested_process(
      Core::MonthlyStatus::EnsureOpen.call(user:, date: starts_on)
    )
  end

  def validate_starts_on_window(category:, starts_on:, **)
    if category.goal_ends_on.present? && starts_on.beginning_of_month > category.goal_ends_on.beginning_of_month
      input.errors.add(:starts_on, :after_ends_on)

      return Failure(:invalid_input, input:)
    end

    Continue()
  end

  def resolve_existing_goal(category:, starts_on:, **)
    existing_goal = find_goal_by_starts_on(category:, starts_on:)
    old_value = existing_goal&.value || category.goal_on(starts_on)&.value

    Continue(existing_goal:, old_value:)
  end

  def reject_same_value(value:, old_value:, **)
    return Continue() if old_value.nil? || value != old_value

    input.errors.add(:value, :same_as_previous)

    Failure(:invalid_input, input:)
  end

  def upsert_current_month(category:, existing_goal:, starts_on:, value:, **)
    if existing_goal
      update_existing_goal(existing_goal:, starts_on:, value:)
    else
      create_goal(category:, starts_on:, value:)
    end
  end

  def apply_following_months_policy(category:, starts_on:, change_for_next_months:, old_value:, user:, **)
    if change_for_next_months
      destroy_following_goals(category:, starts_on:)
    else
      ensure_next_month_with_previous_value(category:, starts_on:, old_value:, user:)
    end
  end

  def destroy_following_goals(category:, starts_on:)
    case deps.goal_repository.destroy_after(category:, starts_on:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :goal_change_failed)
      Failure(:goal_change_failed, input:)
    end
  end

  def ensure_next_month_with_previous_value(category:, starts_on:, old_value:, user:)
    return Continue() if old_value.nil?

    next_starts_on = starts_on.beginning_of_month.next_month
    return Continue() if category.goal_ends_on.present? && next_starts_on > category.goal_ends_on.beginning_of_month
    return Continue() if month_closed?(user:, date: next_starts_on)
    return Continue() if find_goal_by_starts_on(category:, starts_on: next_starts_on)

    create_goal(category:, starts_on: next_starts_on, value: old_value)
  end

  def reload_category(user:, category:, **)
    case deps.category_repository.find_by_id(user:, id: category.id)
    in Solid::Success(category:) then Continue(category:)
    in Solid::Failure
      input.errors.add(:base, :goal_change_failed)
      Failure(:goal_change_failed, input:)
    end
  end

  def update_existing_goal(existing_goal:, value:, **)
    case deps.goal_repository.update(goal: existing_goal, attributes: { value: })
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :goal_change_failed)
      Failure(:goal_change_failed, input:)
    end
  end

  def create_goal(category:, starts_on:, value:)
    case deps.goal_repository.create(category:, starts_on:, value:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :goal_change_failed)
      Failure(:goal_change_failed, input:)
    end
  end

  def find_goal_by_starts_on(category:, starts_on:)
    case deps.goal_repository.find_by_starts_on(category:, starts_on:)
    in Solid::Success(goal:) then goal
    in Solid::Failure(type: :goal_not_found) then nil
    end
  end

  def month_closed?(user:, date:)
    case deps.monthly_status_repository.find(user_id: user.id, month: date.month, year: date.year)
    in Solid::Success(monthly_status:) then monthly_status.closed?
    in Solid::Failure(type: :monthly_status_not_found) then false
    end
  end
end
