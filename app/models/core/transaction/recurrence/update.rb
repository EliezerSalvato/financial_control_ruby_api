class Core::Transaction::Recurrence::Update < ApplicationSolidProcess
  deps do
    attribute :recurrence_repository, default: -> { Transaction::Adapters.recurrence_repository }

    validates :recurrence_repository, kind_of: Core::Transaction::Recurrence::Repository::Interface
  end

  input do
    attribute :transaction
    attribute :recurrence_type, :string
    attribute :starts_on, :date
    attribute :ends_on, :date
    attribute :value, :decimal

    validates :transaction, presence: true
    validates :transaction, kind_of: Core::Transaction::Entity
    validates :value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end

  def call(attributes)
    return Continue() if input.transaction.completed_or_canceled?

    Given(attributes)
      .and_then(:validate_pending_recurrence)
      .and_then(:validate_recurrence_window)
      .and_then(:upsert_recurrence)
  end

  private

  def validate_pending_recurrence(transaction:, recurrence_type:, starts_on:, ends_on:, **)
    return Continue() unless transaction.pending?

    Core::Transaction::RecurrenceType.validate_compatibility_with_ends_on(
      input.errors,
      recurrence_type:,
      starts_on: starts_on || transaction.recurrences.map(&:starts_on).min,
      ends_on:
    )

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end


  def validate_recurrence_window(transaction:, starts_on:, ends_on:, **)
    return Continue() if starts_on.blank? && ends_on.blank?

    starts_on_for_window = starts_on || transaction.recurrences.map(&:starts_on).min
    return Continue() if starts_on_for_window.blank? || ends_on.blank?

    if starts_on_for_window > ends_on
      input.errors.add(starts_on.present? ? :starts_on : :ends_on, starts_on.present? ? :after_ends_on : :before_starts_on)
      return Failure(:invalid_input, input:)
    end

    latest_starts_on = transaction.recurrences.map(&:starts_on).compact.max
    if transaction.active? && latest_starts_on.present? && ends_on < latest_starts_on
      input.errors.add(:ends_on, :before_existing_recurrence)
      return Failure(:invalid_input, input:)
    end

    Continue()
  end

  def upsert_recurrence(transaction:, starts_on:, value:, **)
    return Continue() unless transaction.pending?
    return Continue() if starts_on.nil? && value.nil?

    case deps.recurrence_repository.find_latest(transaction:)
    in Solid::Success(recurrence:)
      attributes = {}
      attributes[:starts_on] = starts_on unless starts_on.nil?
      attributes[:value] = value unless value.nil?

      case deps.recurrence_repository.update(recurrence:, attributes:)
      in Solid::Success then Continue()
      in Solid::Failure(errors:)
        add_errors_to_input(errors)
        Failure(:recurrence_update_failed, errors:)
      end
    in Solid::Failure(type: :recurrence_not_found)
      return Continue() if starts_on.blank? || value.blank?

      case deps.recurrence_repository.create(transaction:, starts_on:, value:)
      in Solid::Success then Continue()
      in Solid::Failure(errors:)
        add_errors_to_input(errors)
        Failure(:recurrence_creation_failed, errors:)
      end
    end
  end
end
