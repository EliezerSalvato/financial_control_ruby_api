class Core::Transaction::Settlement::Creation < ApplicationSolidProcess
  deps do
    attribute :transaction_repository, default: -> { Transaction::Adapters.repository }
    attribute :settlement_repository, default: -> { Transaction::Adapters.settlement_repository }
    attribute :account_repository, default: -> { Account::Adapters.repository }
    attribute :credit_card_repository, default: -> { CreditCard::Adapters.repository }

    validates :transaction_repository, kind_of: Core::Transaction::Repository::Interface
    validates :settlement_repository, kind_of: Core::Transaction::Settlement::Repository::Interface
    validates :account_repository, kind_of: Core::Account::Repository::Interface
    validates :credit_card_repository, kind_of: Core::CreditCard::Repository::Interface
  end

  input do
    attribute :user
    attribute :transaction_id, :string
    attribute :occurred_on, :date
    attribute :value, :decimal
    attribute :settled_on, :date, default: -> { Date.current }

    validates :user, :transaction_id, :occurred_on, :value, :settled_on, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :value, numericality: { greater_than_or_equal_to: 0 }
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:find_transaction)
        .and_then(:calculate_installment_number)
        .and_then(:calculate_limit_consumption)
        .and_then(:create_settlement)
        .and_then(:apply_financial_effects)
        .and_then(:advance_transaction_status)
        .and_expose(:transaction_settled, %i[settlement already_settled])
    }
  end

  private

  def find_transaction(user:, transaction_id:, **)
    case deps.transaction_repository.find_by_id(user:, id: transaction_id)
    in Solid::Success(transaction:) then Continue(transaction:)
    in Solid::Failure(type: :transaction_not_found) then Failure(:transaction_not_found)
    end
  end

  def calculate_installment_number(transaction:, occurred_on:, **)
    return Continue(installment_number: nil) if transaction.recurrence_type == Core::Transaction::RecurrenceType::ONE_TIME

    starts_on = transaction.recurrences.min_by(&:starts_on).starts_on
    months = ((occurred_on.year * 12) + occurred_on.month) - ((starts_on.year * 12) + starts_on.month)

    Continue(installment_number: months + 1)
  end

  def calculate_limit_consumption(transaction:, value:, installment_number:, **)
    return Continue(limit_consumed: nil) unless transaction.credit_card_payment?

    Continue(limit_consumed: limit_consumed_for(transaction:, value:, installment_number:))
  end

  def create_settlement(transaction:, occurred_on:, settled_on:, value:, installment_number:, limit_consumed:, **)
    result = deps.settlement_repository.create(
      transaction_id: transaction.id,
      occurred_on:,
      settled_on:,
      value:,
      installment_number:,
      **dependencies_attributes(transaction, limit_consumed)
    )

    case result
    in Solid::Success(settlement:)
      Continue(settlement:, already_settled: result.already_settled?)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :settlement_creation_failed)
      Failure(:transaction_settlement_creation_failed, input:)
    end
  end

  def apply_financial_effects(already_settled:, user:, settlement:, transaction:, value:, **)
    return Continue() if already_settled

    if settlement.for_account?
      apply_account_balance(user:, account_id: settlement.account_id, value:, kind: transaction.kind)
    elsif settlement.for_transfer_between_accounts?
      apply_transfer_balances(user:, settlement:, value:)
    elsif settlement.for_credit_card?
      apply_credit_card_limit(user:, credit_card_id: transaction.credit_card_id, limit_consumed: settlement.limit_consumed)
    else
      Continue()
    end
  end

  def advance_transaction_status(already_settled:, transaction:, occurred_on:, **)
    return Continue() if already_settled

    status = next_status(transaction, occurred_on)
    return Continue() if status.blank? || status == transaction.status

    case deps.transaction_repository.update(transaction:, attributes: { status: })
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :settlement_creation_failed)
      Failure(:transaction_settlement_creation_failed, input:)
    end
  end

  def limit_consumed_for(transaction:, value:, installment_number:)
    return value unless transaction.limit_consumption_type == Core::Transaction::LimitConsumptionType::UPFRONT

    case transaction.recurrence_type
    when Core::Transaction::RecurrenceType::INSTALLMENT
      installment_number == 1 ? value * transaction.installments_count : 0
    else
      value
    end
  end

  def dependencies_attributes(transaction, limit_consumed)
    if transaction.credit_card_payment?
      { limit_consumed: }
    elsif transaction.transfer_between_accounts?
      { source_account_id: transaction.source_account_id, destination_account_id: transaction.destination_account_id }
    else
      { account_id: transaction.account_id }
    end
  end

  def apply_account_balance(user:, account_id:, value:, kind:)
    operation = kind == Core::Transaction::Kind::INCOME ? Core::Account::BalanceOperation::ADD : Core::Account::BalanceOperation::SUBTRACT

    adjust_account_balance(user:, account_id:, amount: value, operation:)
  end

  def apply_transfer_balances(user:, settlement:, value:)
    case adjust_account_balance(
      user:,
      account_id: settlement.source_account_id,
      amount: value,
      operation: Core::Account::BalanceOperation::SUBTRACT
    )
    in Solid::Success
      adjust_account_balance(
        user:,
        account_id: settlement.destination_account_id,
        amount: value,
        operation: Core::Account::BalanceOperation::ADD
      )
    in Solid::Failure => failure then failure
    end
  end

  def apply_credit_card_limit(user:, credit_card_id:, limit_consumed:)
    return Continue() if limit_consumed.zero?

    case deps.credit_card_repository.find_by_id(user:, id: credit_card_id)
    in Solid::Success(credit_card:)
      adjust_credit_card_limit(
        credit_card:,
        amount: limit_consumed,
        operation: Core::CreditCard::AvailableLimitOperation::SUBTRACT
      )
    in Solid::Failure
      input.errors.add(:base, :settlement_creation_failed)
      Failure(:transaction_settlement_creation_failed, input:)
    end
  end

  def adjust_account_balance(user:, account_id:, amount:, operation:)
    case deps.account_repository.find_by_id(user:, id: account_id)
    in Solid::Success(account:)
      result = deps.account_repository.adjust_balance(account:, amount:, operation:)

      case result
      in Solid::Success then Continue()
      in Solid::Failure(errors:) then propagate_adjustment_failure(result.type, errors)
      end
    in Solid::Failure
      input.errors.add(:base, :settlement_creation_failed)
      Failure(:transaction_settlement_creation_failed, input:)
    end
  end

  def adjust_credit_card_limit(credit_card:, amount:, operation:)
    result = deps.credit_card_repository.adjust_available_limit(credit_card:, amount:, operation:)

    case result
    in Solid::Success then Continue()
    in Solid::Failure(errors:) then propagate_adjustment_failure(result.type, errors)
    end
  end

  def next_status(transaction, occurred_on)
    case transaction.recurrence_type
    when Core::Transaction::RecurrenceType::ONE_TIME
      Core::Transaction::Status::COMPLETED
    when Core::Transaction::RecurrenceType::INSTALLMENT
      if installment_completed?(transaction, occurred_on)
        Core::Transaction::Status::COMPLETED
      elsif transaction.pending?
        Core::Transaction::Status::ACTIVE
      end
    when Core::Transaction::RecurrenceType::RECURRING
      Core::Transaction::Status::ACTIVE if transaction.pending?
    end
  end

  def installment_completed?(transaction, occurred_on)
    return false if transaction.ends_on.blank? || transaction.ends_on > occurred_on

    case deps.settlement_repository.count_for(transaction_id: transaction.id)
    in Solid::Success(count:) then count == transaction.installments_count
    else false
    end
  end

  def propagate_adjustment_failure(type, errors)
    add_errors_to_input(errors)
    input.errors.add(:base, type)
    Failure(type, input:)
  end
end
