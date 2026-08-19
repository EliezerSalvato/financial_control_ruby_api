require "rails_helper"

RSpec.describe Transaction::Tagging::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:tag) { create(:tag, user:) }
  let(:transaction_record) { create(:transaction, user:, tags: [ tag ]) }
  let(:transaction) { Transaction::Mapper.to_entity(transaction_record) }

  describe "#sync" do
    it "keeps existing taggings and is idempotent" do
      transaction

      expect {
        result = repository.sync(transaction:, tag_ids: [ tag.id ])

        expect(result).to be_a(Solid::Success)
        expect(result.type).to eq(:taggings_replaced)
      }.not_to change(Transaction::Tagging::Record, :count)
    end

    it "replaces taggings with the given ids" do
      other_tag = create(:tag, user:, name: "Other")

      result = repository.sync(transaction:, tag_ids: [ other_tag.id ])

      expect(result).to be_a(Solid::Success)
      expect(transaction_record.taggings.reload.map(&:tag_id)).to eq([ other_tag.id ])
    end

    it "returns Failure instead of raising when a unique constraint is violated" do
      allow(Transaction::Tagging::Record).to receive(:create_or_find_by)
        .and_raise(ActiveRecord::RecordNotUnique.new("duplicate"))

      result = repository.sync(transaction:, tag_ids: [ tag.id ])

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:taggings_replace_failed)
      expect(result.value[:errors]).to be_a(Core::Errors)
    end
  end
end
