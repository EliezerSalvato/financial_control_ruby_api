class Core::MonthlyStatus::Closing::ValidationErrorNotifying < ApplicationSolidProcess
  MONTHLY_STATUS_NOTIFIABLE_TYPE = "MonthlyStatus::Record"

  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
  end

  input do
    attribute :user_id, :string
    attribute :pending, default: -> { [] }

    validates :user_id, presence: true
    validates :pending, kind_of: Array
  end

  def call(attributes)
    Given(attributes)
      .and_then(:validate_pending)
      .and_then(:notify_failures)
  end

  private

  def validate_pending(pending:, **)
    pending.each do |item|
      item = item.to_h.symbolize_keys
      next if item[:month].present? && item[:year].present?

      input.errors.add(:pending, :invalid_item)
      return Failure(:invalid_input, input:)
    end

    Continue()
  end

  def notify_failures(user_id:, pending:, **)
    notifications = I18n.with_locale(locale_for(user_id:)) do
      pending.map { |item| notification_for(item) }
    end

    result = Notification.create_all(user_id:, notifications:, broadcast_kind: "monthly_status.errors")

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

  def notification_for(item)
    item = item.to_h.symbolize_keys
    period = format("%02d/%d", item[:month], item[:year])

    {
      kind: "monthly_status.closing.errors",
      title: I18n.t("monthly_status.notifications.closing_failure.title", period:),
      body: closing_body(item),
      data: {
        month: item[:month],
        year: item[:year]
      }.merge(
        {
          pending_occurrences: item[:pending_occurrences],
          pending_invoices: item[:pending_invoices],
          failure: item[:failure]
        }.compact
      ),
      dedup_keys: %w[month year]
    }.merge(notifiable_for(item[:monthly_status_id]))
  end

  def notifiable_for(id)
    return {} if id.blank?

    { notifiable_type: MONTHLY_STATUS_NOTIFIABLE_TYPE, notifiable_id: id }
  end

  def closing_body(item)
    if item[:failure].present?
      type = item[:failure].to_s
      message = I18n.t("monthly_status.notifications.failure_types.#{type}", default: type)
      return I18n.t("monthly_status.notifications.closing_failure.body_failure", message:)
    end

    occurrences = Array(item[:pending_occurrences]).filter_map do |occurrence|
      occurrence.to_h.symbolize_keys[:description]
    end
    invoices_count = Array(item[:pending_invoices]).size

    I18n.t(
      "monthly_status.notifications.closing_failure.body_pending",
      occurrences: occurrences.join(", ").presence || "—",
      invoices_count:
    )
  end
end
