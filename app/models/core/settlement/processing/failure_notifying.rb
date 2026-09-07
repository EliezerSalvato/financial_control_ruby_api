class Core::Settlement::Processing::FailureNotifying < ApplicationSolidProcess
  INVOICE_KIND = "invoice"
  TRANSACTION_NOTIFIABLE_TYPE = "Transaction::Record"
  CREDIT_CARD_NOTIFIABLE_TYPE = "CreditCard::Record"

  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
  end

  input do
    attribute :user_id, :string
    attribute :month, :integer
    attribute :year, :integer
    attribute :failures, default: -> { [] }

    validates :user_id, :month, :year, presence: true
    validates :month, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
    validates :year, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 9999 }
    validates :failures, kind_of: Array
  end

  def call(attributes)
    Given(attributes)
      .and_then(:notify_failures)
  end

  private

  def notify_failures(user_id:, month:, year:, failures:, **)
    notifications = I18n.with_locale(locale_for(user_id:)) do
      failures.map { |failure| notification_for(failure, month:, year:) }
    end

    result = Notification.create_all(user_id:, notifications:, broadcast_kind: "settlement.errors")

    case result
    in Solid::Success(notifications:) then Continue(notifications:)
    in Solid::Success then Continue()
    else
      with_nested_process(result, persist_failure: :notifications_creation_failed)
    end
  end

  def locale_for(user_id:)
    Core::User::Locale.for(user_id:, user_repository: deps.user_repository)
  end

  def notification_for(failure, month:, year:)
    failure = failure.to_h.symbolize_keys
    period = format("%02d/%d", month, year)

    case failure[:kind].to_s
    when INVOICE_KIND then invoice_notification(failure, month:, year:, period:)
    else transaction_notification(failure, month:, year:, period:)
    end
  end

  def transaction_notification(failure, month:, year:, period:)
    {
      kind: "transaction.validation.errors",
      title: transaction_title(description: failure[:description], period:),
      body: failure_body(failure),
      data: {
        type: failure[:type].to_s,
        item_kind: failure[:kind].to_s,
        month:,
        year:,
        occurred_on: failure[:occurred_on]
      },
      dedup_keys: %w[month year occurred_on]
    }.merge(notifiable_for(TRANSACTION_NOTIFIABLE_TYPE, failure[:transaction_id]))
  end

  def invoice_notification(failure, month:, year:, period:)
    {
      kind: "credit_card_invoice.validation.errors",
      title: invoice_title(credit_card_name: failure[:credit_card_name], period:),
      body: failure_body(failure),
      data: {
        type: failure[:type].to_s,
        month:,
        year:,
        due_date: failure[:due_date]
      },
      dedup_keys: %w[month year due_date]
    }.merge(notifiable_for(CREDIT_CARD_NOTIFIABLE_TYPE, failure[:credit_card_id]))
  end

  def transaction_title(description:, period:)
    if description.present?
      I18n.t("settlement.notifications.transaction_failure.title", description:, period:)
    else
      I18n.t("settlement.notifications.transaction_failure.title_without_description", period:)
    end
  end

  def invoice_title(credit_card_name:, period:)
    if credit_card_name.present?
      I18n.t("settlement.notifications.credit_card_invoice_failure.title", credit_card_name:, period:)
    else
      I18n.t("settlement.notifications.credit_card_invoice_failure.title_without_name", period:)
    end
  end

  def notifiable_for(type, id)
    return {} if id.blank?

    { notifiable_type: type, notifiable_id: id }
  end

  def failure_body(failure)
    type = failure[:type].to_s
    translated = I18n.t("settlement.notifications.failure_types.#{type}", default: nil)
    return translated if translated

    # Item messages carry the attribute prefix (e.g. "Current balance Insufficient balance"),
    # so they are only used when the type has no dedicated translation.
    Array(failure[:messages]).compact_blank.join(", ").presence || type
  end
end
