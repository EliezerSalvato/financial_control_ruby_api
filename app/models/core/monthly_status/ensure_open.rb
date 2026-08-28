class Core::MonthlyStatus::EnsureOpen < ApplicationSolidProcess
  deps do
    attribute :monthly_status_repository, default: -> { MonthlyStatus::Adapters.repository }
    attribute :credit_card_repository, default: -> { CreditCard::Adapters.repository }

    validates :monthly_status_repository, kind_of: Core::MonthlyStatus::Repository::Interface
    validates :credit_card_repository, kind_of: Core::CreditCard::Repository::Interface
  end

  input do
    attribute :user
    attribute :date, :date
    attribute :payment_method, :string
    attribute :credit_card_id, :string

    validates :user, presence: true, kind_of: Core::User::Entity
    validates :date, presence: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:resolve_reference_month)
      .and_then(:find_or_create_monthly_status)
      .and_then(:reject_closed_month)
      .and_expose(:monthly_status_is_open, %i[monthly_status reference_month])
  end

  private

  def resolve_reference_month(user:, date:, payment_method:, credit_card_id:, **)
    if payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD && credit_card_id.present?
      resolve_billing_cycle_month(user:, credit_card_id:, date:)
    else
      Continue(reference_month: Data.define(:month, :year).new(month: date.month, year: date.year))
    end
  end

  def resolve_billing_cycle_month(user:, credit_card_id:, date:)
    case deps.credit_card_repository.billing_cycle_month(user:, credit_card_id:, date:)
    in Solid::Success(month:, year:)
      Continue(reference_month: Data.define(:month, :year).new(month:, year:))
    in Solid::Failure(type: :credit_card_not_found)
      input.errors.add(:credit_card_id, :not_found)
      Failure(:invalid_input, input:)
    end
  end

  def find_or_create_monthly_status(user:, reference_month:, **)
    case deps.monthly_status_repository.find_or_create(user_id: user.id, month: reference_month.month, year: reference_month.year)
    in Solid::Success(monthly_status:) then Continue(monthly_status:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:monthly_status_creation_failed, input:)
    end
  end

  def reject_closed_month(monthly_status:, **)
    return Continue() unless monthly_status.closed?

    input.errors.add(:base, :monthly_status_closed)
    Failure(:monthly_status_closed, input:)
  end
end
