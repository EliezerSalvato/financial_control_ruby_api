module API::V1
  class User::Password::ResetsController < BaseController
    skip_before_action :authenticate_user!

    def create
      case ::User.send_reset_password_instructions(permitted_create_params)
      in Solid::Success
        render_json_with_success(status: :ok, message: I18n.t("user.password.reset_instructions.success"))
      in Solid::Failure(input:)
        render_json_with_model_errors(input)
      else
        render_json_with_error(status: :unprocessable_content, message: I18n.t("user.password.reset_instructions.failure"))
      end
    end

    def update
      case ::User.reset_password(permitted_update_params)
      in Solid::Success
        render_json_with_success(status: :ok, message: I18n.t("user.password.reset.success"))
      in Solid::Failure(input:)
        render_json_with_model_errors(input)
      else
        render_json_with_error(status: :unprocessable_content, message: I18n.t("user.password.reset.failure"))
      end
    end

    private

    def permitted_create_params
      params.permit(:email)
    end

    def permitted_update_params
      params.permit(:token, :password, :password_confirmation)
    end
  end
end
