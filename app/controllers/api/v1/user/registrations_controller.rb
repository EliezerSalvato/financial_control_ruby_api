class API::V1::User::RegistrationsController < API::V1::BaseController
  skip_before_action :authenticate_user!

  def create
    case User.register(permitted_params)
    in Solid::Success(user:)
      render_json_with_success(status: :created, message: I18n.t("user.registration.success"), data: { user: User::Serializer.new(user) })
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("user.registration.failure"))
    end
  end

  private

  def permitted_params
    params.permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end
end
