class API::V1::GoalsController < API::V1::BaseController
  def index
    case Goal.list(list_params.merge(user: current_user))
    in Solid::Success(goal_transactions:)
      data = Goal::Serializer.new(goal_transactions)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("goal.errors.invalid_period"))
    end
  end

  def targets
    case Goal.list_targets(list_params.merge(user: current_user))
    in Solid::Success(goal_targets:)
      data = Goal::Target::Serializer.new(goal_targets)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("goal.errors.invalid_period"))
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
