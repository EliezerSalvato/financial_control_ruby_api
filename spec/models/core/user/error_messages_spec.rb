require "rails_helper"

# Domain errors are translated through the Input's i18n_key, which follows the process
# namespace. Moving or renaming a process silently orphans its keys in the YAML files,
# and `raise_on_missing_translations` only guards the locale the suite runs in.
RSpec.describe "Core::User domain error messages" do
  let(:app_locales) do
    Rails.root.glob("config/locales/**/*.yml").flat_map { |path| YAML.load_file(path).keys }.uniq.map(&:to_sym)
  end

  let(:error_usages) do
    Rails.root.glob("app/models/core/user/**/*.rb").flat_map do |path|
      usages = path.read.scan(/errors\.add\(:(\w+), :(\w+)\)/).uniq

      next [] if usages.empty?

      process = path.relative_path_from(Rails.root.join("app/models")).sub_ext("").to_s.camelize.constantize

      usages.map { |attribute, type| [ process, attribute.to_sym, type.to_sym ] }
    end
  end

  def translatable?(process, attribute, type)
    process::Input.new.errors.generate_message(attribute, type)

    true
  rescue I18n::MissingTranslationData
    false
  end

  it "collects the error usages it is meant to check" do
    expect(app_locales).to contain_exactly(:en, :"pt-BR")
    expect(error_usages).to include([ Core::User::Password::Reset::SendInstructions, :email, :not_found ])
  end

  it "translates every domain error in every locale supported by the app" do
    untranslated = app_locales.flat_map do |locale|
      I18n.with_locale(locale) do
        error_usages
          .reject { |process, attribute, type| translatable?(process, attribute, type) }
          .map { |process, attribute, type| "[#{locale}] #{process}: #{attribute}.#{type}" }
      end
    end

    expect(untranslated).to be_empty
  end
end
