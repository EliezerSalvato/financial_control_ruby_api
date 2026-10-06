require "rails_helper"

RSpec.describe Transaction::Import::Rule::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }
  let(:rule_attributes) { { name: "Delivery", pattern: "Ifd" } }

  describe "#list" do
    it "returns the user's rules and pagination" do
      first = create(:transaction_import_rule, user:, position: 1)
      second = create(:transaction_import_rule, user:, position: 2)
      create(:transaction_import_rule)

      result = repository.list(user: user_entity, filters: {}, sorting: "position asc", page: 1, per_page: 25)

      expect(result.type).to eq(:import_rules_listed)
      expect(result.value[:import_rules].map(&:id)).to eq([ first.id, second.id ])
      expect(result.value[:pagination]).to have_attributes(count: 2)
    end

    it "returns invalid_filters when pagination raises" do
      allow(Pagination).to receive(:paginate).and_raise(ArgumentError)

      expect(repository.list(user: user_entity, filters: {}, sorting: "position asc", page: 1, per_page: 25).type).to eq(:invalid_filters)
    end
  end

  describe "#list_active" do
    it "returns only the user's active rules ordered by position" do
      later = create(:transaction_import_rule, user:, position: 5)
      earlier = create(:transaction_import_rule, user:, position: 1)
      create(:transaction_import_rule, :inactive, user:)
      create(:transaction_import_rule)

      result = repository.list_active(user: user_entity)

      expect(result.value[:import_rules].map(&:id)).to eq([ earlier.id, later.id ])
    end
  end

  describe "#find_by_id" do
    it "returns the entity" do
      tag_ids = create_list(:tag, 2, user:).map(&:id)
      rule = create(
        :transaction_import_rule, user:, target_column: "title",
        effects_attributes: [ { effect_type: "add_tags", tag_ids: tag_ids }, { effect_type: "replace_text", match_type: "regex", pattern: "x+", replacement: "X", target_column: "title" } ]
      )

      entity = repository.find_by_id(user: user_entity, id: rule.id).value[:import_rule]

      expect(entity).to have_attributes(id: rule.id, target_column: "title")
      expect(entity.effects).to match(
        [
          have_attributes(position: 0, effect_type: "add_tags", tag_ids:),
          have_attributes(position: 1, effect_type: "replace_text", match_type: "regex", pattern: "x+", replacement: "X", target_column: "title")
        ]
      )
    end

    it "fails for another user's rule" do
      expect(repository.find_by_id(user: user_entity, id: create(:transaction_import_rule).id).type).to eq(:import_rule_not_found)
    end
  end

  describe "#exists?" do
    it "compares names case-insensitively and can exclude a rule" do
      rule = create(:transaction_import_rule, user:, name: "Delivery")

      expect(repository.exists?(user: user_entity, name: "delivery")).to be(true)
      expect(repository.exists?(user: user_entity, name: "delivery", excluding_id: rule.id)).to be(false)
      expect(repository.exists?(user: user_entity, name: "other")).to be(false)
    end
  end

  describe "writes" do
    it "creates, updates and destroys a rule" do
      entity = repository.create(user: user_entity, attributes: rule_attributes).value[:import_rule]

      updated = repository.update(import_rule: entity, attributes: { name: "Food" }).value[:import_rule]

      expect(updated.name).to eq("Food")
      expect(updated.effects).to be_empty
      expect(repository.destroy(import_rule: updated).type).to eq(:import_rule_destroyed)
      expect(Transaction::Import::Rule::Record.count).to eq(0)
    end

    it "creates the rule with its effects" do
      effects = [ { position: 0, effect_type: "set_category", category_id: create(:category, user:).id }, { position: 1, effect_type: "replace_text", pattern: "x", replacement: "" } ]

      entity = repository.create(user: user_entity, attributes: rule_attributes.merge(effects:)).value[:import_rule]

      expect(entity.effects.map(&:effect_type)).to eq(%w[set_category replace_text])
      expect(Transaction::Import::Rule::Effect::Record.count).to eq(2)
    end

    it "replaces the effects on update, keeping them when not given" do
      rule = create(:transaction_import_rule, user:, effects_attributes: [ { effect_type: "replace_text" } ])
      entity = Transaction::Import::Rule::Mapper.to_entity(rule)

      renamed = repository.update(import_rule: entity, attributes: { name: "Renamed" }).value[:import_rule]
      replaced = repository.update(
        import_rule: renamed,
        attributes: { effects: [ { position: 0, effect_type: "add_tags", tag_ids: [ SecureRandom.uuid_v7 ] } ] }
      ).value[:import_rule]
      cleared = repository.update(import_rule: replaced, attributes: { effects: [] }).value[:import_rule]

      expect(renamed.effects.map(&:effect_type)).to eq(%w[replace_text])
      expect(replaced.effects.map(&:effect_type)).to eq(%w[add_tags])
      expect(cleared.effects).to be_empty
      expect(Transaction::Import::Rule::Effect::Record.count).to eq(0)
    end

    it "keeps the previous effects when the update does not persist" do
      rule = create(:transaction_import_rule, user:, effects_attributes: [ { effect_type: "replace_text" } ])
      entity = Transaction::Import::Rule::Mapper.to_entity(rule)

      result = repository.update(import_rule: entity, attributes: { match_type: "glob", effects: [] })

      expect(result.type).to eq(:import_rule_update_failed)
      expect(rule.reload.effects.map(&:effect_type)).to eq(%w[replace_text])
    end

    it "returns Failure when create does not persist" do
      result = repository.create(user: user_entity, attributes: rule_attributes.merge(match_type: "glob"))

      expect(result.type).to eq(:import_rule_creation_failed)
      expect(result.value[:errors].messages).to be_present
    end

    it "returns Failure when update does not persist" do
      entity = Transaction::Import::Rule::Mapper.to_entity(create(:transaction_import_rule, user:))

      expect(repository.update(import_rule: entity, attributes: { match_type: "glob" }).type).to eq(:import_rule_update_failed)
    end

    it "returns Failure when destroy does not persist" do
      entity = Transaction::Import::Rule::Mapper.to_entity(create(:transaction_import_rule, user:))
      allow_any_instance_of(Transaction::Import::Rule::Record).to receive(:destroy).and_return(false)

      expect(repository.destroy(import_rule: entity).type).to eq(:import_rule_destruction_failed)
    end
  end
end
