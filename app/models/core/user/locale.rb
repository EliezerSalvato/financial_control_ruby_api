module Core::User::Locale
  extend self

  def for(user_id:, user_repository:)
    case user_repository.find_by_id(id: user_id)
    in Solid::Success(user:) then resolve(user.configs.to_h["locale"])
    else default
    end
  end

  def resolve(value)
    available(value) || default
  end

  def available(value)
    return if value.blank?

    tag = value.to_s.strip
    available = I18n.available_locales.map(&:to_s)
    return tag if available.include?(tag)

    language = tag.split("-", 2).first
    available.find { |locale| locale.split("-", 2).first == language }
  end

  def default
    I18n.default_locale.to_s
  end
end
