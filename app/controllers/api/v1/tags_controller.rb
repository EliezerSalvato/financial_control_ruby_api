class API::V1::TagsController < API::V1::BaseController
  def index
    case Tag.list(list_params.merge(user: current_user))
    in Solid::Success(tags:, pagination:)
      data = Tag::Serializer.new(tags)

      render_json_with_success(status: :ok, meta: pagination, **data)
    in Solid::Failure(type: :invalid_filters)
      render_json_with_error(status: :bad_request, message: I18n.t("tag.errors.invalid_filters"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :bad_request, message: I18n.t("tag.errors.invalid_filters"))
    end
  end

  def show
    case Tag.find(id: params[:id], user: current_user)
    in Solid::Success(tag:)
      data = Tag::Serializer.new(tag)

      render_json_with_success(status: :ok, **data)
    in Solid::Failure(type: :tag_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("tag.errors.not_found"))
    else
      render_json_with_error(status: :not_found, message: I18n.t("tag.errors.not_found"))
    end
  end

  def create
    case Tag.create(permitted_params.merge(user: current_user))
    in Solid::Success(tag:)
      data = Tag::Serializer.new(tag)

      render_json_with_success(status: :created, message: I18n.t("tag.creation.success"), **data)
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("tag.creation.failure"))
    end
  end

  def update
    case Tag.update(permitted_params.merge(id: params[:id], user: current_user))
    in Solid::Success(tag:)
      data = Tag::Serializer.new(tag)

      render_json_with_success(status: :ok, message: I18n.t("tag.update.success"), **data)
    in Solid::Failure(type: :tag_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("tag.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("tag.update.failure"))
    end
  end

  def destroy
    case Tag.destroy(id: params[:id], user: current_user)
    in Solid::Success
      render_json_with_success(status: :ok, message: I18n.t("tag.deletion.success"))
    in Solid::Failure(type: :tag_not_found)
      render_json_with_error(status: :not_found, message: I18n.t("tag.errors.not_found"))
    in Solid::Failure(input:)
      render_json_with_model_errors(input)
    else
      render_json_with_error(status: :unprocessable_content, message: I18n.t("tag.deletion.failure"))
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
    params.require(:tag).permit(:name, :color, :active)
  end
end
