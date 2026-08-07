require "rails_helper"

RSpec.describe Tag::Record, type: :model do
  describe "defaults" do
    it "defaults active to true" do
      expect(create(:tag).active).to be(true)
    end
  end
end
