class Core::CreditCard::InvoiceSettlement::Creation < ApplicationSolidProcess
  deps do
    attribute :credit_card_repository, default: -> { CreditCard::Adapters.repository }
    attribute :invoice_settlement_repository, default: -> { CreditCard::Adapters.invoice_settlement_repository }
    attribute :account_repository, default: -> { Account::Adapters.repository }

    validates :credit_card_repository, kind_of: Core::CreditCard::Repository::Interface
    validates :invoice_settlement_repository, kind_of: Core::CreditCard::InvoiceSettlement::Repository::Interface
    validates :account_repository, kind_of: Core::Account::Repository::Interface
  end

  input do
    attribute :user
    attribute :credit_card_id, :string
    attribute :payment_account_id, :string
    attribute :opening_date, :date
    attribute :closing_date, :date
    attribute :due_date, :date
    attribute :total_value, :decimal
    attribute :settled_on, :date, default: -> { Date.current }

    validates :user, :credit_card_id, :payment_account_id, :opening_date, :closing_date, :due_date, :total_value, :settled_on, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :total_value, numericality: { greater_than_or_equal_to: 0 }
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:find_credit_card)
        .and_then(:create_invoice_settlement)
        .and_then(:debit_payment_account)
        .and_then(:release_available_limit)
        .and_then(:link_occurrences)
        .and_expose(:credit_card_invoice_settled, %i[invoice_settlement already_settled])
    }
  end

  private

  def find_credit_card(user:, credit_card_id:, **)
    case deps.credit_card_repository.find_by_id(user:, id: credit_card_id)
    in Solid::Success(credit_card:) then Continue(credit_card:)
    in Solid::Failure(type: :credit_card_not_found) then Failure(:credit_card_not_found)
    end
  end

  def create_invoice_settlement(credit_card:, payment_account_id:, opening_date:, closing_date:, due_date:, total_value:, settled_on:, **)
    result = deps.invoice_settlement_repository.create(
      credit_card_id: credit_card.id,
      payment_account_id:,
      opening_date:,
      closing_date:,
      due_date:,
      total_value:,
      released_limit: total_value,
      settled_on:
    )

    case result
    in Solid::Success(invoice_settlement:)
      Continue(invoice_settlement:, already_settled: result.already_settled?)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :invoice_settlement_creation_failed)
      Failure(:credit_card_invoice_settlement_creation_failed, input:)
    end
  end

  def debit_payment_account(already_settled:, user:, payment_account_id:, total_value:, **)
    return Continue() if already_settled

    case deps.account_repository.find_by_id(user:, id: payment_account_id)
    in Solid::Success(account:)
      result = deps.account_repository.adjust_balance(
        account:,
        amount: total_value,
        operation: Core::Account::BalanceOperation::SUBTRACT
      )

      case result
      in Solid::Success then Continue()
      in Solid::Failure(errors:) then propagate_adjustment_failure(result.type, errors)
      end
    in Solid::Failure
      input.errors.add(:base, :invoice_settlement_creation_failed)
      Failure(:credit_card_invoice_settlement_creation_failed, input:)
    end
  end

  def release_available_limit(already_settled:, credit_card:, total_value:, **)
    return Continue() if already_settled

    result = deps.credit_card_repository.adjust_available_limit(
      credit_card:,
      amount: total_value,
      operation: Core::CreditCard::AvailableLimitOperation::ADD
    )

    case result
    in Solid::Success then Continue()
    in Solid::Failure(errors:) then propagate_adjustment_failure(result.type, errors)
    end
  end

  def link_occurrences(already_settled:, invoice_settlement:, **)
    return Continue() if already_settled

    case deps.invoice_settlement_repository.link_occurrences(invoice_settlement:)
    in Solid::Success then Continue()
    end
  end

  def propagate_adjustment_failure(type, errors)
    add_errors_to_input(errors)
    input.errors.add(:base, type)
    Failure(type, input:)
  end
end
