class API::V1::User::Email::ConfirmationsController < API::V1::BaseController
  skip_before_action :authenticate_user!

  def create
    case User.confirm_email(permitted_params)
    in Solid::Success
      render_json_with_success(status: :ok, message: I18n.t("user.email.confirmation.success"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("user.email.confirmation.failure"))
    end
  end

  private

  def permitted_params
    params.permit(:token)
  end
end
