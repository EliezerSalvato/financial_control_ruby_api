class API::V1::NotificationsController < API::V1::BaseController
  def index
    case Notification.list(list_params.merge(user_id: current_user.id))
    in Solid::Success(notifications:, pagination:, unread_count:)
      data = Notification::Serializer.new(notifications)

      render_json_with_success(status: :ok, meta: pagination.to_h.merge(unread_count:), **data)
    in Solid::Failure(type: :invalid_cursor)
      render_json_with_error(status: :bad_request, message: I18n.t("notification.errors.invalid_cursor"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("notification.errors.invalid_cursor"))
    end
  end

  def show
    case Notification.find(id: params[:id], user_id: current_user.id)
    in Solid::Success(notification:)
      data = Notification::Serializer.new(notification)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(type: :notification_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("notification.errors.not_found"))
    else
      render_json_with_error(status: :not_found, message: I18n.t("notification.errors.not_found"))
    end
  end

  def read
    case Notification.mark_as_read(id: params[:id], user_id: current_user.id)
    in Solid::Success(notification:)
      data = Notification::Serializer.new(notification)

      render_json_with_success(status: :ok, message: I18n.t("notification.read.success"), **data)
    in Solid::Failure(type: :notification_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("notification.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("notification.read.failure"))
    end
  end

  def read_all
    case Notification.mark_all_as_read(user_id: current_user.id)
    in Solid::Success(count:)
      render_json_with_success(status: :ok, message: I18n.t("notification.read_all.success"), meta: { count: })
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("notification.read_all.failure"))
    end
  end

  private

  def list_params
    { after: params[:after].presence, limit: params[:limit], unread: params[:unread] }.compact
  end
end
