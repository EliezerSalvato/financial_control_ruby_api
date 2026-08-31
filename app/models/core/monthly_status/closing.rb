class Core::MonthlyStatus::Closing < ApplicationSolidProcess
  ACCOUNT_PAYMENT_METHOD = "account"

  deps do
    attribute :monthly_status_repository, default: -> { MonthlyStatus::Adapters.repository }
    attribute :monthly_statement_repository, default: -> { MonthlyStatement::Adapters.repository }
    attribute :transaction_settlement_repository, default: -> { Transaction::Adapters.settlement_repository }
    attribute :credit_card_invoice_settlement_repository, default: -> { CreditCard::Adapters.invoice_settlement_repository }

    validates :monthly_status_repository, kind_of: Core::MonthlyStatus::Repository::Interface
    validates :monthly_statement_repository, kind_of: Core::MonthlyStatement::Repository::Interface
    validates :transaction_settlement_repository, kind_of: Core::Transaction::Settlement::Repository::Interface
    validates :credit_card_invoice_settlement_repository, kind_of: Core::CreditCard::InvoiceSettlement::Repository::Interface
  end

  input do
    attribute :user_id, :string
    attribute :month, :integer
    attribute :year, :integer

    validates :user_id, :month, :year, presence: true
    validates :month, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
    validates :year, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 9999 }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:load_monthly_status)
      .and_then(:reject_current_or_future_month)
      .and_then(:list_statement)
      .and_then(:list_transfers)
      .and_then(:check_account_and_transfer_settlements)
      .and_then(:check_credit_card_invoices)
      .and_then(:close_month)
  end

  private

  def load_monthly_status(user_id:, month:, year:, **)
    case deps.monthly_status_repository.find(user_id:, month:, year:)
    in Solid::Success(monthly_status:) then Continue(monthly_status:)
    in Solid::Failure(type: :monthly_status_not_found) then Failure(:monthly_status_not_found)
    end
  end

  def reject_current_or_future_month(month:, year:, **)
    today = Date.current
    month_start = Date.new(year, month, 1)

    return Continue() if month_start < today.beginning_of_month

    input.errors.add(:base, :monthly_status_not_closeable)
    Failure(:monthly_status_not_closeable, input:)
  end

  def list_statement(user_id:, month:, year:, **)
    case deps.monthly_statement_repository.list(user_id:, month:, year:)
    in Solid::Success(monthly_statements:) then Continue(monthly_statements:)
    end
  end

  def list_transfers(user_id:, month:, year:, **)
    case deps.monthly_statement_repository.list_transfers(user_id:, month:, year:)
    in Solid::Success(monthly_statement_transfers:) then Continue(monthly_statement_transfers:)
    end
  end

  def check_account_and_transfer_settlements(monthly_statements:, monthly_statement_transfers:, month:, year:, **)
    entries = account_and_transfer_entries(monthly_statements, monthly_statement_transfers)
    occurred_on_range = Date.new(year, month, 1)..Date.new(year, month, -1)

    case deps.transaction_settlement_repository.settled_keys(transaction_ids: entries.map(&:id), occurred_on_range:)
    in Solid::Success(keys:)
      settled = keys.to_set
      pending_occurrences = entries.filter_map { |entry| pending_occurrence_for(entry, settled) }

      Continue(pending_occurrences:)
    end
  end

  def check_credit_card_invoices(monthly_statements:, **)
    invoice_keys = distinct_invoice_keys(monthly_statements)

    case deps.credit_card_invoice_settlement_repository.paid_keys(
      credit_card_ids: invoice_keys.map(&:first),
      due_dates: invoice_keys.map(&:last)
    )
    in Solid::Success(keys:)
      paid = keys.to_set
      pending_invoices = invoice_keys.filter_map do |credit_card_id, due_date|
        next if paid.include?([ credit_card_id, due_date ])

        { credit_card_id:, due_date: }
      end

      Continue(pending_invoices:)
    end
  end

  def close_month(monthly_status:, pending_occurrences:, pending_invoices:, **)
    if pending_occurrences.any? || pending_invoices.any?
      return Success(:monthly_status_kept_open, monthly_status:, pending_occurrences:, pending_invoices:)
    end

    case deps.monthly_status_repository.close(monthly_status:)
    in Solid::Success(monthly_status:) then Success(:monthly_status_closed, monthly_status:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :monthly_status_closing_failed)

      Failure(:monthly_status_closing_failed, input:)
    end
  end

  def account_and_transfer_entries(monthly_statements, monthly_statement_transfers)
    account_items = monthly_statements.select { |item| item.payment_method == ACCOUNT_PAYMENT_METHOD }

    account_items + monthly_statement_transfers
  end

  def pending_occurrence_for(entry, settled)
    return if settled.include?([ entry.id, entry.current_recurrence_on ])

    { transaction_id: entry.id, occurred_on: entry.current_recurrence_on, description: entry.description }
  end

  def distinct_invoice_keys(monthly_statements)
    monthly_statements
      .select { |item| item.payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD }
      .map { |item| [ item.resource_id, item.due_date ] }
      .uniq
  end
end
