class Core::Transaction::Recurrence::Creation < ApplicationSolidProcess
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

    validates :recurrence_type, :starts_on, :value, presence: true
    validates :transaction, kind_of: Core::Transaction::Entity
    validates :value, numericality: { greater_than_or_equal_to: 0 }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:validate_recurrence)
      .and_then(:create_recurrence)
  end

  private

  def validate_recurrence(recurrence_type:, starts_on:, ends_on:, **)
    Core::Transaction::RecurrenceType.validate_compatibility_with_ends_on(input.errors, recurrence_type:, starts_on:, ends_on:)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def create_recurrence(transaction:, starts_on:, value:, **)
    case deps.recurrence_repository.create(transaction:, starts_on:, value:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:recurrence_creation_failed, errors:)
    end
  end
end
