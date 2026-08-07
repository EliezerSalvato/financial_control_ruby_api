require "rails_helper"

RSpec.describe Category::Record, type: :model do
  describe "defaults" do
    it "defaults active to true" do
      expect(create(:category).active).to be(true)
    end
  end
end
