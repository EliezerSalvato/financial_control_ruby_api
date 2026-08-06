class API::V1::User::Password::ChangesController < API::V1::BaseController
  def update
    case User.change_password(permitted_params.merge(user: current_user))
    in Solid::Success
      render_json_with_success(status: :ok, message: I18n.t("user.password.change.success"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("user.password.change.failure"))
    end
  end

  private

  def permitted_params
    params.permit(:current_password, :password, :password_confirmation)
  end
end
