class API::V1::Category::GoalsController < API::V1::BaseController
  def update
    case Category.change_goal(permitted_params.merge(category_id: params[:category_id], user: current_user))
    in Solid::Success(category:)
      data = Category::Serializer.new(category)

      render_json_with_success(status: :ok, message: I18n.t("category.goal.change.success"), **data)
    in Solid::Failure(type: :category_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("category.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("category.goal.change.failure"))
    end
  end

  private

  def permitted_params
    params.require(:category_goal).permit(:value, :starts_on, :change_for_next_months)
  end
end
