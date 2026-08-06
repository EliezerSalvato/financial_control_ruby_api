class API::V1::User::Session::RefreshesController < API::V1::BaseController
  skip_before_action :authenticate_user!

  def update
    case User.refresh_session(permitted_params)
    in Solid::Success(token:, refresh_token:, user:, remember_me:)
      set_refresh_token_as_cookie(refresh_token:, remember_me:) if refresh_token.present?

      render_json_with_success(status: :ok, data: { token:, user: User::Serializer.new(user) })
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("user.session.refresh.failure"))
    end
  end

  private

  def params_with_refresh_token
    params.merge(refresh_token: cookies.encrypted["refresh_token"])
  end

  def permitted_params
    params_with_refresh_token.permit(:refresh_token, :remember_me)
  end
end
