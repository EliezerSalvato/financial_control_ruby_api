class API::V1::User::AuthenticationsController < API::V1::BaseController
  skip_before_action :authenticate_user!

  def create
    case User.authenticate(permitted_params)
    in Solid::Success(token:, refresh_token:, user:, remember_me:)
      set_refresh_token_as_cookie(refresh_token:, remember_me:) if refresh_token.present?

      render_json_with_success(status: :ok, data: { token:, user: User::Serializer.new(user) })
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("user.authentication.failure"))
    end
  end

  private

  def params_with_metadata
    params.merge(request_metadata)
  end

  def permitted_params
    params_with_metadata.permit(:email, :password, :remember_me, :user_agent, :ip_address)
  end
end
