class API::V1::SettlementsController < API::V1::BaseController
  def processing
    user_id = current_user.id
    month = permitted_params[:month]
    year = permitted_params[:year]

    unless MonthlyStatus::Record.find_by(user_id:, month:, year:)&.processing?
      Settlement::ProcessJob.perform_later(user_id:, month:, year:, reference_date: permitted_params[:reference_date])
    end

    render_json_with_success(status: :accepted, message: I18n.t("settlement.processing.enqueued"))
  end

  private

  def permitted_params
    params.require(:settlement).permit(:month, :year, :reference_date)
  end
end
