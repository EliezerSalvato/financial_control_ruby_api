class API::V1::Transaction::RecurrencesController < API::V1::BaseController
  def create
    case Transaction.change_recurrence(permitted_params.merge(transaction_id: params[:transaction_id], user: current_user))
    in Solid::Success(transaction:)
      data = Transaction::Serializer.new(transaction)

      render_json_with_success(status: :ok, message: I18n.t("transaction.recurrence.change.success"), **data)
    in Solid::Failure(type: :transaction_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("transaction.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("transaction.recurrence.change.failure"))
    end
  end

  private

  def permitted_params
    params.require(:transaction_recurrence).permit(:value, :starts_on, :change_for_next_months)
  end
end
