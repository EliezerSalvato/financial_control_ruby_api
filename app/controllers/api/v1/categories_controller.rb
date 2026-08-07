class API::V1::CategoriesController < API::V1::BaseController
  def index
    case Category.list(list_params.merge(user: current_user))
    in Solid::Success(categories:, pagination:)
      data = Category::Serializer.new(categories)

      render_json_with_success(status: :ok, meta: pagination, **data)
    in Solid::Failure(type: :invalid_filters)
      render_json_with_error(status: :bad_request, message: I18n.t("category.errors.invalid_filters"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("category.errors.invalid_filters"))
    end
  end

  def show
    case Category.find(id: params[:id], user: current_user)
    in Solid::Success(category:)
      data = Category::Serializer.new(category)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(type: :category_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("category.errors.not_found"))
    else
      render_json_with_error(status: :not_found, message: I18n.t("category.errors.not_found"))
    end
  end

  def create
    case Category.create(permitted_params.merge(user: current_user))
    in Solid::Success(category:)
      data = Category::Serializer.new(category)

      render_json_with_success(status: :created, message: I18n.t("category.creation.success"), **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("category.creation.failure"))
    end
  end

  def update
    case Category.update(permitted_params.merge(id: params[:id], user: current_user))
    in Solid::Success(category:)
      data = Category::Serializer.new(category)

      render_json_with_success(status: :ok, message: I18n.t("category.update.success"), **data)
    in Solid::Failure(type: :category_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("category.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("category.update.failure"))
    end
  end

  def destroy
    case Category.destroy(id: params[:id], user: current_user)
    in Solid::Success
      render_json_with_success(status: :ok, message: I18n.t("category.deletion.success"))
    in Solid::Failure(type: :category_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("category.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("category.deletion.failure"))
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
    params.require(:category).permit(:name, :color, :active)
  end
end
