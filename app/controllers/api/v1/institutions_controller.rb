class API::V1::InstitutionsController < API::V1::BaseController
  def index
    case Institution.list(list_params.merge(user: current_user))
    in Solid::Success(institutions:, pagination:)
      data = Institution::Serializer.new(institutions)

      render_json_with_success(status: :ok, meta: pagination, **data)
    in Solid::Failure(type: :invalid_filters)
      render_json_with_error(status: :bad_request, message: I18n.t("institution.errors.invalid_filters"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("institution.errors.invalid_filters"))
    end
  end

  def show
    case Institution.find(id: params[:id], user: current_user)
    in Solid::Success(institution:)
      data = Institution::Serializer.new(institution)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(type: :institution_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("institution.errors.not_found"))
    else
      render_json_with_error(status: :not_found, message: I18n.t("institution.errors.not_found"))
    end
  end

  def create
    case Institution.create(permitted_params.merge(user: current_user))
    in Solid::Success(institution:)
      data = Institution::Serializer.new(institution)

      render_json_with_success(status: :created, message: I18n.t("institution.creation.success"), **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("institution.creation.failure"))
    end
  end

  def update
    case Institution.update(permitted_params.merge(id: params[:id], user: current_user))
    in Solid::Success(institution:)
      data = Institution::Serializer.new(institution)

      render_json_with_success(status: :ok, message: I18n.t("institution.update.success"), **data)
    in Solid::Failure(type: :institution_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("institution.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("institution.update.failure"))
    end
  end

  def destroy
    case Institution.destroy(id: params[:id], user: current_user)
    in Solid::Success
      render_json_with_success(status: :ok, message: I18n.t("institution.deletion.success"))
    in Solid::Failure(type: :institution_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("institution.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("institution.deletion.failure"))
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
    params.require(:institution).permit(:name, :logo_key, :active)
  end
end
