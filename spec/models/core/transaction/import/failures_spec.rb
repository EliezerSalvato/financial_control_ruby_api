require "rails_helper"

RSpec.describe "import process failure branches" do
  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }
  let(:errors) { Core::Errors.new(base: [ "invalid" ]) }
  let(:rule_repository) { Transaction::Adapters.import_rule_repository }

  def failure(type = :failed, **value) = Solid::Failure(type, **value)

  describe "rule processes" do
    it "fails the creation when the repository cannot persist" do
      allow(rule_repository).to receive(:exists?).and_return(false)
      allow(rule_repository).to receive(:create).and_return(failure(:import_rule_creation_failed, errors:))

      result = Core::Transaction::Import::Rule::Creation.call(user: user_entity, name: "Rule", pattern: "x", effects: [ { effect_type: "skip" } ])

      expect(result.type).to eq(:import_rule_creation_failed)
    end

    it "fails the update when the repository cannot persist" do
      rule = create(:transaction_import_rule, user:)
      allow(rule_repository).to receive(:update).and_return(failure(:import_rule_update_failed, errors:))

      result = Core::Transaction::Import::Rule::Update.call(user: user_entity, id: rule.id, name: "Other")

      expect(result.type).to eq(:import_rule_update_failed)
    end

    it "fails the deletion when the repository cannot persist" do
      rule = create(:transaction_import_rule, user:)
      allow(rule_repository).to receive(:destroy).and_return(failure(:import_rule_destruction_failed))

      result = Core::Transaction::Import::Rule::Deletion.call(user: user_entity, id: rule.id)

      expect(result.type).to eq(:import_rule_destruction_failed)
    end

    it "returns invalid_filters when listing fails" do
      allow(rule_repository).to receive(:list).and_return(failure(:invalid_filters))

      result = Core::Transaction::Import::Rule::Listing.call(user: user_entity)

      expect(result.type).to eq(:invalid_filters)
      expect(result.value[:input].errors.details[:q]).to be_present
    end
  end

  describe Core::Transaction::Import::Confirmation do
    it "fails when there are too many rows" do
      result = described_class.call(user: user_entity, import_id: SecureRandom.uuid_v7, rows: Array.new(1001) { {} })

      expect(result.value[:input].errors.details[:rows].pluck(:error)).to eq([ :too_many_rows ])
    end

    it "fails when a row is not a hash" do
      result = described_class.call(user: user_entity, import_id: SecureRandom.uuid_v7, rows: [ "x" ])

      expect(result.value[:input].errors.details[:rows].pluck(:error)).to eq([ :invalid ])
    end
  end

  describe Core::Transaction::Import::PersistRow do
    let(:category) { create(:category, user:) }
    let(:account) { create(:account, user:) }
    let(:attributes) do
      {
        user_id: user.id, date: "2026-10-01", description: "Coffee", amount: "5", kind: "expense", payment_method: "pix",
        account_id: account.id, category_id: category.id
      }
    end

    it "fails when the category cannot be created" do
      allow(Category::Adapters.repository).to receive(:find_or_create_by_name).and_return(failure(:category_creation_failed, errors:))

      result = described_class.call(attributes.except(:category_id).merge(category_name: "Food"))

      expect(result.value[:input].errors.details[:base].pluck(:error)).to eq([ :category_creation_failed ])
    end

    it "fails when the tags cannot be created" do
      allow(Tag::Adapters.repository).to receive(:find_or_create_by_names).and_return(failure(:tag_creation_failed, errors:))

      result = described_class.call(attributes.merge(tag_names: [ "fun" ]))

      expect(result.value[:input].errors.details[:base].pluck(:error)).to eq([ :tag_creation_failed ])
    end

    it "fails when the user does not exist" do
      expect(described_class.call(attributes.merge(user_id: SecureRandom.uuid_v7))).to be_failure(:user_not_found)
    end
  end

  describe Core::Transaction::Import::PreviewRow do
    it "fails when the user does not exist" do
      result = described_class.call(user_id: SecureRandom.uuid_v7, row: 1, data: {}, defaults: {})

      expect(result).to be_failure(:user_not_found)
    end
  end
end
