class API::V1::User::AccountsController < API::V1::BaseController
  def destroy
    case User.delete_account(permitted_params.merge(user: current_user))
    in Solid::Success
      render_json_with_success(status: :ok, message: I18n.t("user.account.deletion.success"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("user.account.deletion.failure"))
    end
  end

  private

  def permitted_params
    params.permit(:password)
  end
end
