class API::V1::Transaction::Import::PreviewsController < API::V1::BaseController
  def create
    case Transaction.preview_import(form_params.merge(user: current_user, **file_params))
    in Solid::Success(import_id:, total_rows:)
      render_json_with_success(
        status: :accepted,
        message: I18n.t("transaction.import.queued"),
        data: { import_id:, total_rows: }
      )
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("transaction.import.failure"))
    end
  end

  private

  FORM_FIELDS = %i[kind payment_method account_id credit_card_id limit_consumption_type installments_count].freeze

  def form_params
    FORM_FIELDS.index_with { |field| params[field] }.select { |_, value| value.is_a?(String) }
  end

  def file_params
    file = params[:file]
    return {} unless file.respond_to?(:read) && file.respond_to?(:original_filename)

    { filename: file.original_filename, file: file.read(Core::Transaction::Import::MAX_FILE_SIZE + 1) }
  end
end
