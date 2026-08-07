class API::V1::BaseController < ApplicationController
  before_action :authenticate_user!

  rescue_from StandardError do |exception|
    Rails.error.report(exception, source: "api/v1")

    message = Rails.env.production? ? I18n.t("user.errors.internal_server_error") : exception.message

    render_json_with_error(status: :internal_server_error, message:)
  end

  rescue_from ActionController::ParameterMissing do |exception|
    render_json_with_error(status: :bad_request, message: exception.message)
  end

  protected

  def authenticate_user!
    return if current_user&.active?

    render_json_with_error(status: :unauthorized, message: I18n.t("user.errors.unauthorized"))
  end

  def current_user
    @current_user ||= User::Mapper.to_entity(
      User::Record.find_signed(bearer_token, purpose: :session_token)
    )
  end

  def set_refresh_token_as_cookie(refresh_token:, remember_me: false)
    cookie_options = {
      value: refresh_token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }

    cookie_options[:expires] = Core::User::Token::REFRESH_TOKEN_EXPIRES_IN if remember_me

    cookies.encrypted[:refresh_token] = cookie_options
  end

  def render_json_with_success(status:, data: nil, message: nil, meta: nil)
    json = { status: :success }

    case data
    when ::Hash then json[:type] = :object
    when ::Array then json[:type] = :collection
    end

    json[:data] = data if data
    json[:message] = message if message
    json[:meta] = meta if meta

    render status:, json:
  end

  def render_json_with_error(status:, message:, details: {})
    render status:, json: { status: :error, message:, details: }
  end

  def render_json_with_model_errors(record)
    message = record.errors.full_messages.join(", ")
    details = record.errors.messages

    render_json_with_error(status: :unprocessable_content, message:, details:)
  end

  private

  def request_metadata
    { ip_address: request.remote_ip, user_agent: request.user_agent }
  end

  def bearer_token
    request.headers["Authorization"]&.remove("Bearer ")
  end

  def ransack_filter_params
    params[:q].to_unsafe_h if params[:q].present?
  end
end
