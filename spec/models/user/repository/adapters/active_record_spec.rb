require "rails_helper"

RSpec.describe User::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  describe "#find_by_id" do
    it "returns Success when the user exists" do
      user = create(:user, :verified)

      result = repository.find_by_id(id: user.id)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:user_found)
      expect(result.value[:user]).to have_attributes(
        id: user.id,
        email: user.email,
        verified: true,
        configs: {}
      )
      expect(result.value[:user]).to be_a(Core::User::Entity)
    end

    it "returns Failure(:user_not_found) when the user does not exist" do
      result = repository.find_by_id(id: SecureRandom.uuid)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:user_not_found)
    end
  end
end
