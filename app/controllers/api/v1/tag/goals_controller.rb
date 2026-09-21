class API::V1::Tag::GoalsController < API::V1::BaseController
  def update
    case Tag.change_goal(permitted_params.merge(tag_id: params[:tag_id], user: current_user))
    in Solid::Success(tag:)
      data = Tag::Serializer.new(tag)

      render_json_with_success(status: :ok, message: I18n.t("tag.goal.change.success"), **data)
    in Solid::Failure(type: :tag_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("tag.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("tag.goal.change.failure"))
    end
  end

  private

  def permitted_params
    params.require(:tag_goal).permit(:value, :starts_on, :change_for_next_months)
  end
end
