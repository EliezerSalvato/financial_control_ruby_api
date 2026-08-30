class Core::Settlement::Processing < ApplicationSolidProcess
  DUE_STATUSES = [ Core::Transaction::Status::PENDING, Core::Transaction::Status::ACTIVE ].freeze

  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :monthly_status_repository, default: -> { MonthlyStatus::Adapters.repository }
    attribute :monthly_statement_repository, default: -> { MonthlyStatement::Adapters.repository }
    attribute :settlement_repository, default: -> { Transaction::Adapters.settlement_repository }
    attribute :invoice_settlement_repository, default: -> { CreditCard::Adapters.invoice_settlement_repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :monthly_status_repository, kind_of: Core::MonthlyStatus::Repository::Interface
    validates :monthly_statement_repository, kind_of: Core::MonthlyStatement::Repository::Interface
    validates :settlement_repository, kind_of: Core::Transaction::Settlement::Repository::Interface
    validates :invoice_settlement_repository, kind_of: Core::CreditCard::InvoiceSettlement::Repository::Interface
  end

  input do
    attribute :user_id, :string
    attribute :month, :integer
    attribute :year, :integer
    attribute :reference_date, :date

    validates :user_id, :month, :year, presence: true
    validates :month, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
    validates :year, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 9999 }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:resolve_reference_date)
      .and_then(:reject_if_previous_month_is_open)
      .and_then(:reject_if_later_month_is_closed)
      .and_then(:find_monthly_status)
      .and_then(:start_processing)
      .and_then(:find_user)
      .and_then(:settle_due_occurrences)
      .and_then(:settle_due_transfers)
      .and_then(:settle_due_credit_card_invoices)
      .and_then(:finish_processing)
      .and_expose(:settlements_completed, %i[settled_count invoices_count failures])
  end

  private

  def find_monthly_status(user_id:, month:, year:, **)
    case deps.monthly_status_repository.find(user_id:, month:, year:)
    in Solid::Success(monthly_status:) then Continue(monthly_status:)
    in Solid::Failure(type: :monthly_status_not_found) then Failure(:monthly_status_not_found)
    end
  end

  def reject_if_previous_month_is_open(user_id:, month:, year:, **)
    previous = Date.new(year, month, 1).prev_month

    case deps.monthly_status_repository.find(user_id:, month: previous.month, year: previous.year)
    in Solid::Success(monthly_status:) if monthly_status.open?
      input.errors.add(:base, :previous_month_open)
      Failure(:previous_month_open, input:)
    else
      Continue()
    end
  end

  def reject_if_later_month_is_closed(user_id:, month:, year:, **)
    return Continue() unless deps.monthly_status_repository.exists_closed_after?(user_id:, month:, year:)

    input.errors.add(:base, :later_month_closed)
    Failure(:later_month_closed, input:)
  end

  def start_processing(monthly_status:, **)
    update_monthly_status(monthly_status:, attributes: { processing: true })
  end

  def resolve_reference_date(month:, year:, reference_date:, **)
    period_start = Date.new(year, month, 1)
    today = Date.current
    current_month_start = today.beginning_of_month

    if period_start > current_month_start
      input.errors.add(:month, :in_the_future)
      return Failure(:invalid_input, input:)
    end

    if period_start < current_month_start
      return Continue(reference_date: Date.new(year, month, -1))
    end

    return Continue() if [ today, today.yesterday ].include?(reference_date)

    input.errors.add(:reference_date, :must_be_today_or_yesterday)
    Failure(:invalid_input, input:)
  end

  def find_user(user_id:, **)
    case deps.user_repository.find_by_id(id: user_id)
    in Solid::Success(user:)
      Continue(user:, settled_count: 0, invoices_count: 0, failures: [])
    in Solid::Failure(type: :user_not_found)
      Failure(:user_not_found)
    end
  end

  def finish_processing(monthly_status:, **)
    update_monthly_status(
      monthly_status:,
      attributes: { processing: false, last_processed_at: Time.current }
    )
  end

  def update_monthly_status(monthly_status:, attributes:)
    case deps.monthly_status_repository.update(monthly_status:, attributes:)
    in Solid::Success(monthly_status:) then Continue(monthly_status:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :monthly_status_update_failed)
      Failure(:monthly_status_update_failed, input:)
    end
  end

  def settle_due_occurrences(user:, month:, year:, reference_date:, settled_count:, failures:, **)
    entities = due_statements(user_id: user.id, month:, year:, reference_date:)

    settled_count, failures = settle_transaction_entities(
      entities,
      user:,
      reference_date:,
      kind: :occurrence,
      settled_count:,
      failures:
    )

    Continue(settled_count:, failures:)
  end

  def settle_due_transfers(user:, month:, year:, reference_date:, settled_count:, failures:, **)
    entities = due_transfers(user_id: user.id, month:, year:, reference_date:)

    settled_count, failures = settle_transaction_entities(
      entities,
      user:,
      reference_date:,
      kind: :transfer,
      settled_count:,
      failures:
    )

    Continue(settled_count:, failures:)
  end

  def settle_due_credit_card_invoices(user:, month:, year:, reference_date:, invoices_count:, failures:, **)
    case deps.invoice_settlement_repository.list_due(user_id: user.id, month:, year:, reference_date:)
    in Solid::Success(due_invoices:)
      due_invoices.each do |due_invoice|
        result = Core::CreditCard::InvoiceSettlement::Creation.call(
          user:,
          credit_card_id: due_invoice.credit_card_id,
          payment_account_id: due_invoice.payment_account_id,
          opening_date: due_invoice.opening_date,
          closing_date: due_invoice.closing_date,
          due_date: due_invoice.due_date,
          total_value: due_invoice.total_value,
          settled_on: reference_date
        )

        case apply_item_result(
          result,
          kind: :invoice,
          credit_card_id: due_invoice.credit_card_id,
          due_date: due_invoice.due_date,
          failures:
        )
        in :settled then invoices_count += 1
        in :failed then next
        end
      end

      Continue(invoices_count:, failures:)
    end
  end

  def due_statements(user_id:, month:, year:, reference_date:)
    case deps.monthly_statement_repository.list(
      user_id:,
      month:,
      year:,
      statuses: DUE_STATUSES,
      on: reference_date
    )
    in Solid::Success(monthly_statements:) then reject_already_settled(monthly_statements)
    end
  end

  def due_transfers(user_id:, month:, year:, reference_date:)
    case deps.monthly_statement_repository.list_transfers(
      user_id:,
      month:,
      year:,
      statuses: DUE_STATUSES,
      on: reference_date
    )
    in Solid::Success(monthly_statement_transfers:) then reject_already_settled(monthly_statement_transfers)
    end
  end

  def reject_already_settled(entities)
    return entities if entities.empty?

    occurred_on_range = entities.map(&:current_recurrence_on).minmax.then { |min, max| min..max }

    case deps.settlement_repository.settled_keys(transaction_ids: entities.map(&:id), occurred_on_range:)
    in Solid::Success(keys:)
      settled = keys.to_set
      entities.reject { |entity| settled.include?([ entity.id, entity.current_recurrence_on ]) }
    end
  end

  def settle_transaction_entities(entities, user:, reference_date:, kind:, settled_count:, failures:)
    entities.each do |entity|
      result = Core::Transaction::Settlement::Creation.call(
        user:,
        transaction_id: entity.id,
        occurred_on: entity.current_recurrence_on,
        value: entity.value,
        settled_on: reference_date
      )

      case apply_item_result(
        result,
        kind:,
        transaction_id: entity.id,
        occurred_on: entity.current_recurrence_on,
        failures:
      )
      in :settled then settled_count += 1
      in :failed then next
      end
    end

    [ settled_count, failures ]
  end

  def apply_item_result(result, kind:, failures:, **identity)
    case result
    in Solid::Success then :settled
    in Solid::Failure(type:, input:)
      failures << { kind:, type:, messages: input.errors.full_messages, **identity }
      :failed
    in Solid::Failure(type:)
      failures << { kind:, type:, messages: [], **identity }
      :failed
    end
  end
end
