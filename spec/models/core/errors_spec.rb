require "rails_helper"

RSpec.describe Core::Errors do
  describe "#any? and #empty?" do
    it "is empty when there are no messages" do
      errors = described_class.new

      expect(errors).to be_empty
      expect(errors.any?).to be(false)
    end

    it "is empty when every attribute has an empty list" do
      errors = described_class.new(name: [], base: [])

      expect(errors).to be_empty
      expect(errors.any?).to be(false)
    end

    it "is present when any attribute has a message" do
      errors = described_class.new(name: [ "is invalid" ])

      expect(errors.any?).to be(true)
      expect(errors.empty?).to be(false)
    end
  end
end
