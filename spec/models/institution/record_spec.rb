require "rails_helper"

RSpec.describe Institution::Record, type: :model do
  describe "defaults" do
    it "defaults active to true" do
      expect(create(:institution).active).to be(true)
    end
  end
end
