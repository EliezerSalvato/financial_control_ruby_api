require "rails_helper"

RSpec.describe Core::Transaction::Import::Rule::Applying do
  let(:row) do
    {
      description: "Ifd*Burger King Parcela 1/3", original_description: "Ifd*Burger King Parcela 1/3",
      source_column: "description", category_name: nil, tag_names: [], recurrence_type: nil
    }
  end

  def effect(effect_type, **attributes)
    Core::Transaction::Import::Rule::Effect::Entity.new(effect_type:, **attributes)
  end

  def rule(effects = [], **overrides)
    Core::Transaction::Import::Rule::Entity.new(
      id: SecureRandom.uuid_v7, user_id: SecureRandom.uuid_v7, name: "Rule", position: 0, active: true, match_type: "contains",
      pattern: "Ifd*", case_sensitive: false, effects: effects.each_with_index.map { |item, position| item.with(position:) }, **overrides
    )
  end

  def tags(*ids) = effect("add_tags", tag_ids: ids)

  def removal(**attributes) = effect("replace_text", pattern: "parcela \\d+/\\d+", match_type: "regex", replacement: "", **attributes)

  let(:tag_a) { SecureRandom.uuid_v7 }
  let(:tag_b) { SecureRandom.uuid_v7 }
  let(:tag_c) { SecureRandom.uuid_v7 }
  let(:category_id) { SecureRandom.uuid_v7 }

  def apply(*rules, row: self.row) = described_class.call(row:, rules:)

  it "returns the row untouched when there are no rules" do
    expect(apply).to eq(row.merge(category_id: nil, installments_count: nil, tag_ids: [], skipped: false, applied_rules: []))
  end

  describe "set_installments_count" do
    let(:row) { super().merge(description: "Shopee *Webcontinental - Parcela 11/12", original_description: "Shopee *Webcontinental - Parcela 11/12") }
    let(:from_text) { effect("set_installments_count", pattern: "parcela\\s+\\d+/(\\d+)", match_type: "regex") }

    def installments(*effects, **overrides) = apply(rule(effects, pattern: "Shopee", **overrides), row:)[:installments_count]

    it "sets a fixed value" do
      expect(installments(effect("set_installments_count", installments_count: 6))).to eq(6)
    end

    it "extracts the value with the first capture group of the regex" do
      expect(installments(from_text)).to eq(12)
    end

    it "reads the original text even after a replace_text effect" do
      expect(installments(removal, from_text)).to eq(12)
    end

    it "keeps the first value found" do
      expect(installments(effect("set_installments_count", installments_count: 6), from_text)).to eq(6)
    end

    it "ignores a regex that does not match or captures less than two" do
      expect(installments(effect("set_installments_count", pattern: "foo(\\d+)", match_type: "regex"))).to be_nil
      expect(installments(effect("set_installments_count", pattern: "Parcela 11/(\\d)", match_type: "regex"))).to be_nil
    end

    it "ignores effects aimed at another text column" do
      expect(installments(from_text.with(target_column: "title"))).to be_nil
    end

    it "ignores a regex that times out" do
      allow_any_instance_of(Regexp).to receive(:match).and_raise(Regexp::TimeoutError)

      expect(installments(from_text)).to be_nil
    end
  end

  it "applies a matching rule without effects" do
    expect(apply(rule)[:applied_rules]).to contain_exactly(include(name: "Rule"))
  end

  it "matches literally, ignoring the case by default" do
    result = apply(rule([ tags(tag_a) ], pattern: "ifd*"))

    expect(result[:tag_ids]).to eq([ tag_a ])
    expect(result[:applied_rules]).to contain_exactly(include(name: "Rule"))
  end

  it "does not treat contains patterns as regular expressions" do
    expect(apply(rule(pattern: "Ifd.*"))[:applied_rules]).to be_empty
  end

  it "honors case sensitivity" do
    expect(apply(rule(pattern: "ifd*", case_sensitive: true))[:applied_rules]).to be_empty
    expect(apply(rule(pattern: "Ifd*", case_sensitive: true))[:applied_rules]).not_to be_empty
  end

  it "matches regular expressions" do
    result = apply(rule([ effect("set_recurrence_type", recurrence_type: "installment") ], match_type: "regex", pattern: "parcela \\d+/\\d+"))

    expect(result[:recurrence_type]).to eq("installment")
  end

  it "only matches the column the rule targets" do
    title_rule = rule([ tags(tag_a) ], target_column: "title")
    description_rule = rule([ tags(tag_b) ], target_column: "description")
    both_rule = rule([ tags(tag_c) ], target_column: "both")

    expect(apply(title_rule, description_rule, both_rule)[:tag_ids]).to eq([ tag_b, tag_c ])
    expect(apply(title_rule, description_rule, both_rule, row: row.merge(source_column: "title"))[:tag_ids]).to eq([ tag_a, tag_c ])
  end

  it "assumes the description column when the row does not say" do
    expect(apply(rule(target_column: "description"), row: row.except(:source_column))[:applied_rules]).not_to be_empty
  end

  it "removes the text matched by the effect pattern, squishing the spaces" do
    result = apply(rule([ removal ]))

    expect(result).to include(description: "Ifd*Burger King", original_description: "Ifd*Burger King Parcela 1/3")
  end

  it "replaces the text matched by the effect pattern, independent of the rule pattern" do
    result = apply(rule([ effect("replace_text", pattern: "Burger King", replacement: "Food") ], pattern: "Ifd*"))

    expect(result[:description]).to eq("Ifd*Food Parcela 1/3")
  end

  it "matches the effect pattern literally and case-insensitively unless it is a regex" do
    literal = effect("replace_text", pattern: "ifd*", replacement: "Food")
    regex = effect("replace_text", pattern: "ifd.*", replacement: "Food")

    expect(apply(rule([ literal ]))[:description]).to eq("FoodBurger King Parcela 1/3")
    expect(apply(rule([ regex ]))[:description]).to eq(row[:description])
  end

  it "replaces the matched text literally, without interpreting backreferences" do
    result = apply(rule([ effect("replace_text", pattern: "Ifd*", replacement: "\\0") ]))

    expect(result[:description]).to eq("\\0Burger King Parcela 1/3")
  end

  it "only changes the text when the effect targets the row column" do
    effects = [ removal(target_column: "title") ]

    expect(apply(rule(effects))[:description]).to eq(row[:description])
    expect(apply(rule(effects), row: row.merge(source_column: "title"))[:description]).to eq("Ifd*Burger King")
  end

  it "keeps the description when the text change would empty it" do
    result = apply(rule([ effect("replace_text", pattern: "Ifd*Burger King Parcela 1/3", replacement: "") ]))

    expect(result[:description]).to eq("Ifd*Burger King Parcela 1/3")
  end

  it "runs the effects in position order" do
    first = effect("replace_text", pattern: "Ifd*", replacement: "Food")
    second = effect("replace_text", pattern: "Food", replacement: "Drink")

    expect(apply(rule([ first, second ]))[:description]).to eq("DrinkBurger King Parcela 1/3")
    expect(apply(rule([ second, first ]))[:description]).to eq("FoodBurger King Parcela 1/3")
  end

  it "evaluates later rules against the changed description" do
    first = rule([ effect("replace_text", pattern: "Ifd*", replacement: "") ], name: "First", pattern: "Ifd*")
    second = rule(name: "Second", pattern: "Ifd*")
    third = rule([ effect("set_category", category_id:) ], name: "Third", pattern: "Burger")

    result = apply(first, second, third)

    expect(result[:applied_rules].pluck(:name)).to eq(%w[First Third])
    expect(result[:category_id]).to eq(category_id)
  end

  it "gives priority to the values from the file, then to the first rule" do
    other_category_id = SecureRandom.uuid_v7
    rules = [
      rule([ effect("set_category", category_id:), effect("set_recurrence_type", recurrence_type: "recurring") ]),
      rule([ effect("set_category", category_id: other_category_id), effect("set_recurrence_type", recurrence_type: "installment") ])
    ]

    expect(apply(*rules)).to include(category_id:, recurrence_type: "recurring")
    expect(apply(*rules, row: row.merge(category_name: "File", recurrence_type: "one_time"))).to include(
      category_name: "File", category_id: nil, recurrence_type: "one_time"
    )
  end

  it "merges the tags of every matching rule without duplicates, keeping the ones from the file apart" do
    result = apply(rule([ tags(tag_a, tag_b) ]), rule([ tags(tag_b, tag_c) ]), row: row.merge(tag_names: [ "Delivery" ]))

    expect(result).to include(tag_ids: [ tag_a, tag_b, tag_c ], tag_names: [ "Delivery" ])
  end

  it "flags the row as skipped and stops evaluating the next rules" do
    first = rule([ effect("skip") ], name: "First")
    second = rule([ tags(tag_a) ], name: "Second")

    result = apply(first, second)

    expect(result).to include(skipped: true, tag_ids: [])
    expect(result[:applied_rules].pluck(:name)).to eq(%w[First])
  end

  it "ignores rules whose regex times out" do
    allow_any_instance_of(Regexp).to receive(:match?).and_raise(Regexp::TimeoutError)

    result = apply(rule([ tags(tag_a) ]))

    expect(result).to include(description: row[:description], tag_ids: [], applied_rules: [])
  end

  it "keeps the description when the text change times out" do
    allow_any_instance_of(String).to receive(:gsub).and_raise(Regexp::TimeoutError)

    result = apply(rule([ removal, tags(tag_a) ]))

    expect(result).to include(description: row[:description], tag_ids: [ tag_a ])
  end
end
