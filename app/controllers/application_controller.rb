class ApplicationController < ActionController::API
  include ActionController::Cookies

  before_action :set_paper_trail_whodunnit

  around_action :switch_locale

  private

  def switch_locale(&action)
    I18n.with_locale(resolve_locale, &action)
  end

  def resolve_locale
    locale_from_cookie || locale_from_accept_language || Core::User::Locale.default
  end

  def locale_from_cookie
    available_locale(cookies[:locale])
  end

  def locale_from_accept_language
    header = request.get_header("HTTP_ACCEPT_LANGUAGE")
    return if header.blank?

    header.split(",").each do |part|
      locale = available_locale(part.split(";", 2).first)
      return locale if locale
    end

    nil
  end

  def available_locale(value)
    Core::User::Locale.available(value)
  end
end
