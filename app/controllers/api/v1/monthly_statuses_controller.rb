class API::V1::MonthlyStatusesController < API::V1::BaseController
  def show
    case MonthlyStatus.find(show_params.merge(user: current_user))
    in Solid::Success(monthly_status:)
      data = MonthlyStatus::Serializer.new(monthly_status)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(type: :monthly_status_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("monthly_status.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :not_found, message: I18n.t("monthly_status.errors.not_found"))
    end
  end

  def update
    case MonthlyStatus.update(permitted_params.merge(user: current_user))
    in Solid::Success(monthly_status:)
      data = MonthlyStatus::Serializer.new(monthly_status)

      render_json_with_success(status: :ok, message: I18n.t("monthly_status.update.success"), **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("monthly_status.update.failure"))
    end
  end

  private

  def show_params
    {
      month: params[:month],
      year: params[:year]
    }
  end

  def permitted_params
    params.require(:monthly_status).permit(:month, :year, :status)
  end
end
