class API::V1::Transaction::ImportRulesController < API::V1::BaseController
  def index
    case Transaction.list_import_rules(list_params.merge(user: current_user))
    in Solid::Success(import_rules:, pagination:)
      data = Transaction::Import::Rule::Serializer.new(import_rules)

      render_json_with_success(status: :ok, meta: pagination, **data)
    in Solid::Failure(type: :invalid_filters)
      render_json_with_error(status: :bad_request, message: I18n.t("transaction.import_rule.errors.invalid_filters"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("transaction.import_rule.errors.invalid_filters"))
    end
  end

  def show
    case Transaction.find_import_rule(id: params[:id], user: current_user)
    in Solid::Success(import_rule:)
      data = Transaction::Import::Rule::Serializer.new(import_rule)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(type: :import_rule_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("transaction.import_rule.errors.not_found"))
    else
      render_json_with_error(status: :not_found, message: I18n.t("transaction.import_rule.errors.not_found"))
    end
  end

  def create
    case Transaction.create_import_rule(permitted_params.merge(user: current_user))
    in Solid::Success(import_rule:)
      data = Transaction::Import::Rule::Serializer.new(import_rule)

      render_json_with_success(status: :created, message: I18n.t("transaction.import_rule.creation.success"), **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("transaction.import_rule.creation.failure"))
    end
  end

  def update
    case Transaction.update_import_rule(permitted_params.merge(id: params[:id], user: current_user))
    in Solid::Success(import_rule:)
      data = Transaction::Import::Rule::Serializer.new(import_rule)

      render_json_with_success(status: :ok, message: I18n.t("transaction.import_rule.update.success"), **data)
    in Solid::Failure(type: :import_rule_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("transaction.import_rule.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("transaction.import_rule.update.failure"))
    end
  end

  def destroy
    case Transaction.destroy_import_rule(id: params[:id], user: current_user)
    in Solid::Success
      render_json_with_success(status: :ok, message: I18n.t("transaction.import_rule.deletion.success"))
    in Solid::Failure(type: :import_rule_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("transaction.import_rule.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("transaction.import_rule.deletion.failure"))
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
    params.require(:import_rule).permit(
      :name, :position, :active, :match_type, :pattern, :case_sensitive, :target_column,
      effects: [
        :effect_type, :target_column, :category_id, :recurrence_type, :match_type, :pattern, :replacement, :installments_count, { tag_ids: [] }
      ]
    )
  end
end
