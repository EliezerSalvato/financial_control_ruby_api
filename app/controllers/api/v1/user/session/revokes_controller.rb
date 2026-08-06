class API::V1::User::Session::RevokesController < API::V1::BaseController
  def destroy
    case User.revoke_sessions(user: current_user)
    in Solid::Success
      render_json_with_success(status: :ok, message: I18n.t("user.session.revoke.success"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("user.session.revoke.failure"))
    end
  end
end
