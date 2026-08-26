class API::V1::MonthlyStatementsController < API::V1::BaseController
  def index
    case MonthlyStatement.list(list_params.merge(user: current_user))
    in Solid::Success(monthly_statements:)
      data = MonthlyStatement::Serializer.new(monthly_statements)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("monthly_statement.errors.invalid_period"))
    end
  end

  def transfers
    case MonthlyStatement.list_transfers(list_params.merge(user: current_user))
    in Solid::Success(monthly_statement_transfers:)
      data = MonthlyStatement::Transfer::Serializer.new(monthly_statement_transfers)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("monthly_statement.errors.invalid_period"))
    end
  end

  private

  def list_params
    {
      month: params[:month],
      year: params[:year]
    }
  end
end
