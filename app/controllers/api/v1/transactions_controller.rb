class API::V1::TransactionsController < API::V1::BaseController
  def index
    case Transaction.list(list_params.merge(user: current_user))
    in Solid::Success(transactions:, pagination:)
      data = Transaction::Serializer.new(transactions)

      render_json_with_success(status: :ok, meta: pagination, **data)
    in Solid::Failure(type: :invalid_filters)
      render_json_with_error(status: :bad_request, message: I18n.t("transaction.errors.invalid_filters"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("transaction.errors.invalid_filters"))
    end
  end

  def show
    case Transaction.find(id: params[:id], user: current_user)
    in Solid::Success(transaction:)
      data = Transaction::Serializer.new(transaction)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(type: :transaction_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("transaction.errors.not_found"))
    else
      render_json_with_error(status: :not_found, message: I18n.t("transaction.errors.not_found"))
    end
  end

  def create
    case Transaction.create(permitted_params.merge(user: current_user))
    in Solid::Success(transaction:)
      data = Transaction::Serializer.new(transaction)

      render_json_with_success(status: :created, message: I18n.t("transaction.creation.success"), **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("transaction.creation.failure"))
    end
  end

  def update
    case Transaction.update(permitted_params.merge(id: params[:id], user: current_user))
    in Solid::Success(transaction:)
      data = Transaction::Serializer.new(transaction)

      render_json_with_success(status: :ok, message: I18n.t("transaction.update.success"), **data)
    in Solid::Failure(type: :transaction_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("transaction.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("transaction.update.failure"))
    end
  end

  def cancel
    case Transaction.cancel(id: params[:id], user: current_user)
    in Solid::Success(transaction:)
      data = Transaction::Serializer.new(transaction)

      render_json_with_success(status: :ok, message: I18n.t("transaction.cancellation.success"), **data)
    in Solid::Failure(type: :transaction_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("transaction.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("transaction.cancellation.failure"))
    end
  end

  def destroy
    case Transaction.destroy(id: params[:id], user: current_user)
    in Solid::Success
      render_json_with_success(status: :ok, message: I18n.t("transaction.deletion.success"))
    in Solid::Failure(type: :transaction_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("transaction.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("transaction.deletion.failure"))
    end
  end

  private

  def list_params
    {
      filters: ransack_filter_params,
      sorting: params[:sort].presence,
      page: params[:page],
      per_page: params[:per_page]
    }.compact
  end

  def permitted_params
    params.require(:transaction).permit(
      :category_id,
      :description,
      :kind,
      :payment_method,
      :recurrence_type,
      :starts_on,
      :ends_on,
      :value,
      :limit_consumption_type,
      :account_id,
      :credit_card_id,
      :source_account_id,
      :destination_account_id,
      tag_ids: []
    )
  end
end
