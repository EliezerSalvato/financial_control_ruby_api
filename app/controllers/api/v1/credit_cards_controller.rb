class API::V1::CreditCardsController < API::V1::BaseController
  def index
    case CreditCard.list(list_params.merge(user: current_user))
    in Solid::Success(credit_cards:, pagination:)
      data = CreditCard::Serializer.new(credit_cards)

      render_json_with_success(status: :ok, meta: pagination, **data)
    in Solid::Failure(type: :invalid_filters)
      render_json_with_error(status: :bad_request, message: I18n.t("credit_card.errors.invalid_filters"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("credit_card.errors.invalid_filters"))
    end
  end

  def show
    case CreditCard.find(id: params[:id], user: current_user)
    in Solid::Success(credit_card:)
      data = CreditCard::Serializer.new(credit_card)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(type: :credit_card_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("credit_card.errors.not_found"))
    else
      render_json_with_error(status: :not_found, message: I18n.t("credit_card.errors.not_found"))
    end
  end

  def create
    case CreditCard.create(permitted_params.merge(user: current_user))
    in Solid::Success(credit_card:)
      data = CreditCard::Serializer.new(credit_card)

      render_json_with_success(status: :created, message: I18n.t("credit_card.creation.success"), **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("credit_card.creation.failure"))
    end
  end

  def update
    case CreditCard.update(permitted_params.merge(id: params[:id], user: current_user))
    in Solid::Success(credit_card:)
      data = CreditCard::Serializer.new(credit_card)

      render_json_with_success(status: :ok, message: I18n.t("credit_card.update.success"), **data)
    in Solid::Failure(type: :credit_card_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("credit_card.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("credit_card.update.failure"))
    end
  end

  def destroy
    case CreditCard.destroy(id: params[:id], user: current_user)
    in Solid::Success
      render_json_with_success(status: :ok, message: I18n.t("credit_card.deletion.success"))
    in Solid::Failure(type: :credit_card_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("credit_card.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("credit_card.deletion.failure"))
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
    credit_card_params = params.require(:credit_card)

    if action_name == "update" && params[:id].present?
      credit_card_params.permit(:institution_id, :default_payment_account_id, :name, :total_limit, :network, :allow_negative_available_limit, :active)
    else
      credit_card_params.permit(:institution_id, :default_payment_account_id, :name, :total_limit, :closing_day, :due_day, :network, :allow_negative_available_limit, :active)
    end
  end
end
