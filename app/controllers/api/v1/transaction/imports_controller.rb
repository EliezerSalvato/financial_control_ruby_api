class API::V1::Transaction::ImportsController < API::V1::BaseController
  def create
    case Transaction.confirm_import(import_id: params[:import_id], rows: permitted_rows, user: current_user)
    in Solid::Success(total_rows:)
      render_json_with_success(
        status: :accepted,
        message: I18n.t("transaction.import.queued"),
        data: { import_id: params[:import_id], total_rows: }
      )
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("transaction.import.failure"))
    end
  end

  private

  def permitted_rows
    params.require(:rows)

    params.permit(rows: [
      :row, :create, :source_key, :date, :description, :amount, :kind, :payment_method, :account_id,
      :credit_card_id, :limit_consumption_type, :installments_count, :recurrence_type, :ends_on, :category_id, :category_name,
      { tag_ids: [], tag_names: [] }
    ]).to_h.fetch(:rows, []).map(&:deep_symbolize_keys)
  end
end
