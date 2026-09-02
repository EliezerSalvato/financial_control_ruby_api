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

    validates :user_id, presence: true
    validates :kind, presence: true
    validates :title, presence: true
    validates :data, kind_of: Hash
  end

  def call(attributes)
    Given(attributes)
      .and_then(:validate_notifiable_pair)
      .and_then(:create_notification)
  end

  private

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

  def create_notification(user_id:, kind:, title:, body:, notifiable_type:, notifiable_id:, data:, broadcast:, **)
    notification_attrs = { user_id:, kind:, title:, body:, notifiable_type:, notifiable_id:, data:, broadcast: }

    case deps.notification_repository.create(attributes: notification_attrs)
    in Solid::Success(notification:) then Continue(notification:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :notification_creation_failed)

      Failure(:notification_creation_failed, input:)
    end
  end
end
