class ApplicationController < ActionController::API
  include ActionController::Cookies

  before_action :set_paper_trail_whodunnit

  around_action :switch_locale

  private

  def switch_locale(&action)
    I18n.with_locale(resolve_locale, &action)
  end

  def resolve_locale
    locale_from_cookie || locale_from_accept_language || I18n.default_locale
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
    return if value.blank?

    tag = value.to_s.strip
    available = I18n.available_locales.map(&:to_s)
    return tag if available.include?(tag)

    language = tag.split("-", 2).first
    available.find { |locale| locale.split("-", 2).first == language }
  end
end
