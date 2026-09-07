require "rails_helper"

RSpec.describe Core::User::Locale do
  describe ".available" do
    it "returns the exact available tag" do
      expect(described_class.available("pt-BR")).to eq("pt-BR")
      expect(described_class.available("en")).to eq("en")
    end

    it "returns the language base when the full tag is not available" do
      expect(described_class.available("pt")).to eq("pt-BR")
    end

    it "returns nil for a blank value" do
      expect(described_class.available(nil)).to be_nil
      expect(described_class.available("")).to be_nil
    end

    it "returns nil for an unavailable locale" do
      expect(described_class.available("fr")).to be_nil
    end
  end

  describe ".default" do
    it "returns I18n.default_locale as a String" do
      expect(described_class.default).to eq(I18n.default_locale.to_s)
      expect(described_class.default).to be_a(String)
    end
  end

  describe ".resolve" do
    it "returns the available locale when present" do
      expect(described_class.resolve("pt-BR")).to eq("pt-BR")
    end

    it "falls back to the default locale when unavailable" do
      expect(described_class.resolve("fr")).to eq(described_class.default)
    end
  end

  describe ".for" do
    let(:user_repository) { double("UserRepository") }

    def locale_for(user_id:, user: :missing)
      result =
        if user == :missing
          Solid::Failure(:user_not_found)
        else
          Solid::Success(:user_found, user:)
        end

      allow(user_repository).to receive(:find_by_id).with(id: user_id).and_return(result)
      described_class.for(user_id:, user_repository:)
    end

    it "returns the locale from the user configs" do
      user = instance_double(Core::User::Entity, configs: { "locale" => "pt-BR" })

      expect(locale_for(user_id: "user-id", user:)).to eq("pt-BR")
    end

    it "falls back to the default locale when the configs locale is unavailable" do
      user = instance_double(Core::User::Entity, configs: { "locale" => "fr" })

      expect(locale_for(user_id: "user-id", user:)).to eq(described_class.default)
    end

    it "falls back to the default locale when the user does not exist" do
      expect(locale_for(user_id: SecureRandom.uuid)).to eq(described_class.default)
    end

    it "falls back to the default locale when configs has no locale" do
      user = instance_double(Core::User::Entity, configs: {})

      expect(locale_for(user_id: "user-id", user:)).to eq(described_class.default)
    end
  end
end
