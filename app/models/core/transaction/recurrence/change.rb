class Core::Transaction::Recurrence::Change < ApplicationSolidProcess
  deps do
    attribute :transaction_repository, default: -> { Transaction::Adapters.repository }
    attribute :recurrence_repository, default: -> { Transaction::Adapters.recurrence_repository }
    attribute :monthly_status_repository, default: -> { MonthlyStatus::Adapters.repository }

    validates :transaction_repository, kind_of: Core::Transaction::Repository::Interface
    validates :recurrence_repository, kind_of: Core::Transaction::Recurrence::Repository::Interface
    validates :monthly_status_repository, kind_of: Core::MonthlyStatus::Repository::Interface
  end

  input do
    attribute :user
    attribute :transaction_id, :string
    attribute :starts_on, :date
    attribute :value, :decimal
    attribute :change_for_next_months, :boolean, default: false

    validates :user, :transaction_id, :starts_on, :value, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :value, numericality: { greater_than_or_equal_to: 0 }
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:find_transaction)
        .and_then(:normalize_starts_on)
        .and_then(:reject_invalid_status)
        .and_then(:reject_one_time)
        .and_then(:reject_upfront_limit_consumption)
        .and_then(:ensure_month_is_open)
        .and_then(:validate_starts_on_window)
        .and_then(:resolve_existing_recurrence)
        .and_then(:reject_same_value)
        .and_then(:upsert_current_month)
        .and_then(:apply_following_months_policy)
        .and_then(:reload_transaction)
    }
  end

  private

  def find_transaction(user:, transaction_id:, **)
    case deps.transaction_repository.find_by_id(user:, id: transaction_id)
    in Solid::Success(transaction:) then Continue(transaction:)
    in Solid::Failure(type: :transaction_not_found)
      Failure(:transaction_not_found)
    end
  end

  def normalize_starts_on(transaction:, starts_on:, **)
    first_starts_on = transaction.recurrences.map(&:starts_on).min
    return Continue() if first_starts_on.nil?

    day = [ first_starts_on.day, starts_on.end_of_month.day ].min
    Continue(starts_on: Date.new(starts_on.year, starts_on.month, day))
  end

  def reject_invalid_status(transaction:, **)
    return Continue() if transaction.active?

    input.errors.add(:base, :cannot_be_changed)

    Failure(:invalid_input, input:)
  end

  def reject_one_time(transaction:, **)
    return Continue() unless transaction.recurrence_type == Core::Transaction::RecurrenceType::ONE_TIME

    input.errors.add(:base, :invalid_recurrence_type)
    Failure(:invalid_input, input:)
  end

  def reject_upfront_limit_consumption(transaction:, **)
    return Continue() unless transaction.limit_consumption_type == Core::Transaction::LimitConsumptionType::UPFRONT

    input.errors.add(:base, :upfront_limit_consumption)
    Failure(:invalid_input, input:)
  end

  def ensure_month_is_open(user:, transaction:, starts_on:, **)
    case Core::MonthlyStatus::EnsureOpen.call(
      user:,
      date: starts_on,
      payment_method: transaction.payment_method,
      credit_card_id: transaction.credit_card_id
    )
    in Solid::Success then Continue()
    in Solid::Failure(input:)
      merge_month_status_errors(input)
      Failure(:invalid_input, input: self.input)
    end
  end

  def merge_month_status_errors(nested_input)
    nested_input.errors.details.each do |attribute, errors|
      errors.each do |detail|
        target = starts_on_month_status_error?(detail[:error]) ? :starts_on : attribute
        input.errors.add(target, detail[:error])
      end
    end
  end

  def starts_on_month_status_error?(error)
    error.in?([ :monthly_status_closed, :later_month_closed ])
  end

  def validate_starts_on_window(transaction:, starts_on:, **)
    if transaction.ends_on.present? && starts_on > transaction.ends_on
      input.errors.add(:starts_on, :after_ends_on)

      return Failure(:invalid_input, input:)
    end

    Continue()
  end

  def resolve_existing_recurrence(transaction:, starts_on:, **)
    existing_recurrence = find_recurrence_by_starts_on(transaction:, starts_on:)
    old_value = existing_recurrence&.value || transaction.value_on(starts_on)

    Continue(existing_recurrence:, old_value:)
  end

  def reject_same_value(value:, old_value:, **)
    return Continue() if old_value.nil? || value != old_value

    input.errors.add(:value, :same_as_previous)

    Failure(:invalid_input, input:)
  end

  def upsert_current_month(transaction:, existing_recurrence:, starts_on:, value:, **)
    if existing_recurrence
      update_existing_recurrence(existing_recurrence:, starts_on:, value:)
    else
      create_recurrence(transaction:, starts_on:, value:)
    end
  end

  def apply_following_months_policy(transaction:, starts_on:, change_for_next_months:, old_value:, user:, **)
    if change_for_next_months
      destroy_following_recurrences(transaction:, starts_on:)
    else
      ensure_next_month_with_previous_value(transaction:, starts_on:, old_value:, user:)
    end
  end

  def destroy_following_recurrences(transaction:, starts_on:)
    case deps.recurrence_repository.destroy_after(transaction:, starts_on:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :recurrence_change_failed)
      Failure(:recurrence_change_failed, input:)
    end
  end

  def ensure_next_month_with_previous_value(transaction:, starts_on:, old_value:, user:)
    return Continue() if old_value.nil?

    next_starts_on = next_month_starts_on(transaction:, starts_on:)
    return Continue() if transaction.ends_on.present? && next_starts_on > transaction.ends_on
    return Continue() if month_closed?(user:, date: next_starts_on)
    return Continue() if find_recurrence_by_starts_on(transaction:, starts_on: next_starts_on)

    create_recurrence(transaction:, starts_on: next_starts_on, value: old_value)
  end

  def next_month_starts_on(transaction:, starts_on:)
    following_month = starts_on.beginning_of_month.next_month
    day = first_series_day(transaction) || starts_on.day

    Date.new(following_month.year, following_month.month, [ day, following_month.end_of_month.day ].min)
  end

  def first_series_day(transaction)
    transaction.recurrences.map(&:starts_on).min&.day
  end

  def month_closed?(user:, date:)
    case deps.monthly_status_repository.find(user_id: user.id, month: date.month, year: date.year)
    in Solid::Success(monthly_status:) then monthly_status.closed?
    in Solid::Failure(type: :monthly_status_not_found) then false
    end
  end

  def reload_transaction(user:, transaction:, **)
    case deps.transaction_repository.find_by_id(user:, id: transaction.id)
    in Solid::Success(transaction:) then Continue(transaction:)
    in Solid::Failure
      input.errors.add(:base, :recurrence_change_failed)
      Failure(:recurrence_change_failed, input:)
    end
  end

  def update_existing_recurrence(existing_recurrence:, starts_on:, value:)
    attributes = { value: }
    attributes[:starts_on] = starts_on if existing_recurrence.starts_on != starts_on

    case deps.recurrence_repository.update(recurrence: existing_recurrence, attributes:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :recurrence_change_failed)
      Failure(:recurrence_change_failed, input:)
    end
  end

  def create_recurrence(transaction:, starts_on:, value:)
    case deps.recurrence_repository.create(transaction:, starts_on:, value:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :recurrence_change_failed)
      Failure(:recurrence_change_failed, input:)
    end
  end

  def find_recurrence_by_starts_on(transaction:, starts_on:)
    case deps.recurrence_repository.find_by_starts_on(transaction:, starts_on:)
    in Solid::Success(recurrence:) then recurrence
    in Solid::Failure(type: :recurrence_not_found) then nil
    end
  end
end
