class ApplicationController < ActionController::API
  include ActionController::Cookies

  around_action :switch_locale

  private

  def switch_locale(&action)
    I18n.with_locale(locale_from_cookie, &action)
  end

  def locale_from_cookie
    locale = cookies[:locale].presence

    I18n.available_locales.map(&:to_s).include?(locale) ? locale : I18n.default_locale
  end
end
