class Core::Notification::Creation < ApplicationSolidProcess
  deps do
    attribute :notification_repository, default: -> { Notification::Adapters.repository }

    validates :notification_repository, kind_of: Core::Notification::Repository::Interface
  end

  input do
    attribute :user_id, :string
    attribute :kind, :string
    attribute :title, :string
    attribute :body, :string
    attribute :notifiable_type, :string
    attribute :notifiable_id, :string
    attribute :data, default: -> { {} }
    attribute :broadcast, :boolean, default: true
    attribute :dedup_keys, default: -> { [] }

    validates :user_id, presence: true
    validates :kind, presence: true
    validates :title, presence: true
    validates :data, kind_of: Hash
    validates :dedup_keys, kind_of: Array
  end

  def call(attributes)
    Given(attributes)
      .and_then(:validate_notifiable_pair)
      .and_then(:validate_dedup_keys)
      .and_then(:assign_dedup_key)
      .and_then(:skip_if_duplicate)
      .and_then(:create_notification)
  end

  private

  def validate_dedup_keys(data:, dedup_keys:, **)
    return Continue() if dedup_keys.blank?

    missing = dedup_keys.map(&:to_s) - data.to_h.stringify_keys.keys
    return Continue() if missing.empty?

    input.errors.add(:dedup_keys, :not_in_data, keys: missing.join(", "))
    Failure(:invalid_input, input:)
  end

  def assign_dedup_key(data:, dedup_keys:, **)
    return Continue(dedup_key: nil) if dedup_keys.blank?

    Continue(dedup_key: data.to_h.stringify_keys.slice(*dedup_keys.map(&:to_s)).as_json)
  end

  def skip_if_duplicate(user_id:, kind:, notifiable_type:, notifiable_id:, dedup_key: nil, **)
    return Continue() if dedup_key.blank?

    return Continue() unless deps.notification_repository.exists_unread?(
      user_id:,
      kind:,
      notifiable_type:,
      notifiable_id:,
      data: dedup_key
    )

    Success(:notification_skipped)
  end

  def validate_notifiable_pair(notifiable_type:, notifiable_id:, **)
    type_present = notifiable_type.present?
    id_present = notifiable_id.present?

    return Continue() if type_present == id_present

    if type_present
      input.errors.add(:notifiable_id, :blank)
    else
      input.errors.add(:notifiable_type, :blank)
    end

    Failure(:invalid_input, input:)
  end

  def create_notification(user_id:, kind:, title:, body:, notifiable_type:, notifiable_id:, data:, broadcast:, dedup_key: nil, **)
    notification_attrs = { user_id:, kind:, title:, body:, notifiable_type:, notifiable_id:, data:, broadcast:, dedup_key: }

    case deps.notification_repository.create(attributes: notification_attrs)
    in Solid::Success(type: :notification_skipped) then Success(:notification_skipped)
    in Solid::Success(notification:) then Continue(notification:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :notification_creation_failed)

      Failure(:notification_creation_failed, input:)
    end
  end
end
