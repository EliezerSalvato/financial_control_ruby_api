class API::V1::User::ProfilesController < API::V1::BaseController
  def update
    case User.update_profile(permitted_params.merge(user: current_user))
    in Solid::Success(user:)
      render_json_with_success(status: :ok, message: I18n.t("user.profile.update.success"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("user.profile.update.failure"))
    end
  end

  private

  def permitted_params
    permitted = params.permit(:first_name, :last_name, configs: {})
    configs = params[:configs]

    return permitted if configs.nil? || permitted.key?(:configs)

    permitted.merge(configs:)
  end
end
