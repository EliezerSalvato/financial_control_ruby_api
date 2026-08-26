class API::V1::AccountsController < API::V1::BaseController
  def index
    case Account.list(list_params.merge(user: current_user))
    in Solid::Success(accounts:, pagination:)
      data = Account::Serializer.new(accounts)

      render_json_with_success(status: :ok, meta: pagination, **data)
    in Solid::Failure(type: :invalid_filters)
      render_json_with_error(status: :bad_request, message: I18n.t("account.errors.invalid_filters"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("account.errors.invalid_filters"))
    end
  end

  def show
    case Account.find(id: params[:id], user: current_user)
    in Solid::Success(account:)
      data = Account::Serializer.new(account)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(type: :account_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("account.errors.not_found"))
    else
      render_json_with_error(status: :not_found, message: I18n.t("account.errors.not_found"))
    end
  end

  def create
    case Account.create(permitted_params.merge(user: current_user))
    in Solid::Success(account:)
      data = Account::Serializer.new(account)

      render_json_with_success(status: :created, message: I18n.t("account.creation.success"), **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("account.creation.failure"))
    end
  end

  def update
    case Account.update(permitted_params.merge(id: params[:id], user: current_user))
    in Solid::Success(account:)
      data = Account::Serializer.new(account)

      render_json_with_success(status: :ok, message: I18n.t("account.update.success"), **data)
    in Solid::Failure(type: :account_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("account.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("account.update.failure"))
    end
  end

  def destroy
    case Account.destroy(id: params[:id], user: current_user)
    in Solid::Success
      render_json_with_success(status: :ok, message: I18n.t("account.deletion.success"))
    in Solid::Failure(type: :account_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("account.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("account.deletion.failure"))
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
    account_params = params.require(:account)
    kind = account_params[:kind].presence || account_kind_for_update

    case kind
    when Core::Account::Kind::BANK_ACCOUNT
      account_params.permit(:name, :kind, :institution_id, :bank_account_type, :current_balance, :color, :allow_negative_balance, :active)
    else
      account_params.permit(:name, :kind, :current_balance, :color, :allow_negative_balance, :active)
    end
  end

  def account_kind_for_update
    return unless action_name == "update" && params[:id].present?

    case Account.find(id: params[:id], user: current_user)
    in Solid::Success(account:) then account.kind
    else nil
    end
  end
end
