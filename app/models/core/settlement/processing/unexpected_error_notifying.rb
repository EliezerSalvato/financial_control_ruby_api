class Core::Settlement::Processing::UnexpectedErrorNotifying < ApplicationSolidProcess
  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
  end

  input do
    attribute :user_id, :string
    attribute :month, :integer
    attribute :year, :integer
    attribute :type
    attribute :error, :string

    validates :user_id, :month, :year, :type, presence: true
    validates :month, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
    validates :year, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 9999 }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:notify_error)
  end

  private

  def notify_error(user_id:, type:, error:, month:, year:, **)
    notification = I18n.with_locale(locale_for(user_id:)) do
      period = format("%02d/%d", month, year)

      {
        kind: "settlement.errors",
        title: I18n.t("settlement.notifications.general_error.title", period:),
        body: I18n.t("settlement.notifications.general_error.body"),
        data: { type: type.to_s, month:, year:, error: }.compact,
        dedup_keys: %w[month year type]
      }
    end

    result = Notification.create(user_id:, **notification)

    case result
    in Solid::Success(notification:) then Continue(notification:)
    in Solid::Success then Continue()
    else
      with_nested_process(result, persist_failure: :notification_creation_failed)
    end
  end

  def locale_for(user_id:)
    Core::User::Locale.for(user_id:, user_repository: deps.user_repository)
  end
end
