require "rails_helper"

RSpec.describe "API::V1::Transaction::ImportRules", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }

  def rule_attributes(payload)
    payload.dig("data", "attributes")
  end

  describe "GET /api/v1/transactions/import_rules" do
    def list_rules(query = {}, request_headers = headers)
      get "/api/v1/transactions/import_rules", params: query, headers: request_headers
    end

    context "when authenticated" do
      let!(:second) { create(:transaction_import_rule, user:, name: "Second", position: 2) }
      let!(:first) { create(:transaction_import_rule, user:, name: "First", position: 1) }

      before { create(:transaction_import_rule) }

      it "returns only the user's rules ordered by position" do
        list_rules

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(names).to eq(%w[First Second])
      end

      it "paginates the collection" do
        list_rules(page: 1, per_page: 1)

        expect(response.parsed_body["data"].size).to eq(1)
        expect(response.parsed_body["meta"]).to include("count" => 2, "pages" => 2)
      end

      it "filters by name" do
        list_rules(q: { name_cont: "Sec" })

        expect(response.parsed_body["data"].map { |item| item.dig("attributes", "id") }).to eq([ second.id ])
      end

      it "rejects invalid pagination" do
        list_rules(page: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "page")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_rules({}, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "GET /api/v1/transactions/import_rules/:id" do
    let(:tag) { create(:tag, user:) }
    let(:rule) do
      create(
        :transaction_import_rule, user:, name: "Delivery",
        effects_attributes: [
          { effect_type: "add_tags", tag_ids: [ tag.id ] },
          { effect_type: "replace_text", match_type: "regex", pattern: "Ifd\\*", replacement: "Food", target_column: "title" }
        ]
      )
    end

    def show_rule(id, request_headers = headers)
      get "/api/v1/transactions/import_rules/#{id}", headers: request_headers
    end

    it "returns the rule" do
      show_rule(rule.id)

      expect(response).to have_http_status(:ok)
      expect(rule_attributes(response.parsed_body)).to include(
        "id" => rule.id, "name" => "Delivery", "match_type" => "contains", "target_column" => "both", "active" => true
      )
      expect(rule_attributes(response.parsed_body)["effects"]).to match(
        [
          include("position" => 0, "effect_type" => "add_tags", "tag_ids" => [ tag.id ], "target_column" => "both"),
          include(
            "position" => 1, "effect_type" => "replace_text", "match_type" => "regex", "pattern" => "Ifd\\*",
            "replacement" => "Food", "target_column" => "title"
          )
        ]
      )
    end

    it "returns 404 for another user's rule" do
      show_rule(create(:transaction_import_rule).id)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["message"]).to eq("Import rule not found")
    end

    context "when unauthenticated" do
      subject { show_rule(rule.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "POST /api/v1/transactions/import_rules" do
    def create_rule(params, request_headers = headers)
      post "/api/v1/transactions/import_rules", params: { import_rule: params }, headers: request_headers, as: :json
    end

    let(:category) { create(:category, user:) }
    let(:tag) { create(:tag, user:) }

    it "creates a rule with its effects" do
      expect {
        create_rule(
          name: "Delivery", pattern: "Ifd*", target_column: "title",
          effects: [
            { effect_type: "replace_text", target_column: "title", pattern: "Ifd*", replacement: "" },
            { effect_type: "set_category", category_id: " #{category.id} " },
            { effect_type: "add_tags", tag_ids: [ tag.id, tag.id, " " ] },
            { effect_type: "set_recurrence_type", recurrence_type: "recurring" },
            { effect_type: "replace_text", match_type: "regex", pattern: "Parcela \\d+", replacement: "X" }
          ]
        )
      }.to change(Transaction::Import::Rule::Record, :count).by(1).and change(Transaction::Import::Rule::Effect::Record, :count).by(5)

      expect(response).to have_http_status(:created)
      expect(rule_attributes(response.parsed_body)).to include(
        "name" => "Delivery", "match_type" => "contains", "target_column" => "title", "case_sensitive" => false, "position" => 0
      )
      expect(rule_attributes(response.parsed_body)["effects"]).to match(
        [
          include(
            "position" => 0, "effect_type" => "replace_text", "target_column" => "title", "match_type" => "contains",
            "pattern" => "Ifd*", "replacement" => "", "category_id" => nil
          ),
          include("position" => 1, "effect_type" => "set_category", "category_id" => category.id, "target_column" => "both", "pattern" => nil),
          include("position" => 2, "effect_type" => "add_tags", "tag_ids" => [ tag.id ]),
          include("position" => 3, "effect_type" => "set_recurrence_type", "recurrence_type" => "recurring"),
          include("position" => 4, "effect_type" => "replace_text", "match_type" => "regex", "pattern" => "Parcela \\d+", "replacement" => "X")
        ]
      )
    end

    it "creates a rule with a skip effect" do
      create_rule(name: "Ignore", pattern: "Transfer", effects: [ { effect_type: "skip" } ])

      expect(response).to have_http_status(:created)
      expect(rule_attributes(response.parsed_body)["effects"]).to match([ include("effect_type" => "skip", "pattern" => nil) ])
    end

    it "rejects any field on a skip effect" do
      create_rule(name: "Ignore", pattern: "x", effects: [ { effect_type: "skip", category_id: category.id, pattern: "x", target_column: "title" } ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "effects")).to eq(
        [ "has an unexpected category_id in effect 1", "has an unexpected target_column in effect 1", "has an unexpected pattern in effect 1" ]
      )
    end

    it "rejects a rule without effects" do
      create_rule(name: "Plain", pattern: "x")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "effects")).to eq([ "can't be blank" ])
    end

    it "creates a regex rule" do
      create_rule(name: "Installments", match_type: "regex", pattern: "Parcela \\d+/\\d+", effects: [ { effect_type: "skip" } ])

      expect(response).to have_http_status(:created)
      expect(rule_attributes(response.parsed_body)["match_type"]).to eq("regex")
    end

    it "rejects an invalid regex" do
      create_rule(name: "Broken", match_type: "regex", pattern: "(unclosed")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "pattern")).to eq([ "is not a valid regular expression" ])
    end

    it "rejects invalid attributes" do
      create_rule(name: "", pattern: "x", match_type: "glob", target_column: "amount", position: -1)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["details"].keys).to include("name", "match_type", "target_column", "position")
    end

    it "creates installments count effects, forcing the pattern to be a regex" do
      create_rule(
        name: "Installments", pattern: "Shopee",
        effects: [
          { effect_type: "set_installments_count", installments_count: 6 },
          { effect_type: "set_installments_count", pattern: "Parcela \\d+/(\\d+)", match_type: "contains", target_column: "title" }
        ]
      )

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "attributes", "effects")).to include(
        include("effect_type" => "set_installments_count", "installments_count" => 6, "pattern" => nil),
        include("effect_type" => "set_installments_count", "installments_count" => nil, "match_type" => "regex", "target_column" => "title")
      )
    end

    it "rejects invalid installments count effects" do
      create_rule(
        name: "Broken", pattern: "x",
        effects: [
          { effect_type: "set_installments_count" },
          { effect_type: "set_installments_count", installments_count: 1 },
          { effect_type: "set_installments_count", installments_count: "abc" },
          { effect_type: "set_installments_count", installments_count: 3, pattern: "(\\d+)" },
          { effect_type: "set_installments_count", pattern: "\\d+" },
          { effect_type: "set_installments_count", pattern: "(unclosed" },
          { effect_type: "add_tags", tag_ids: [ tag.id ], installments_count: 3 }
        ]
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "effects")).to eq(
        [
          "has an invalid or missing installments_count in effect 1", "has an invalid or missing installments_count in effect 2",
          "has an invalid or missing installments_count in effect 3", "has an invalid or missing installments_count in effect 4",
          "has an invalid or missing pattern in effect 5", "has an invalid or missing pattern in effect 6",
          "has an unexpected installments_count in effect 7"
        ]
      )
    end

    it "rejects invalid effects" do
      create_rule(
        name: "Broken", pattern: "x",
        effects: [
          { effect_type: "explode" }, {}, { effect_type: "set_category" }, { effect_type: "add_tags", tag_ids: [] },
          { effect_type: "add_tags", tag_ids: [ "nope" ] }, { effect_type: "set_recurrence_type" },
          { effect_type: "set_recurrence_type", recurrence_type: "weekly" }, { effect_type: "replace_text" },
          { effect_type: "replace_text", pattern: "x", replacement: "", target_column: "amount", match_type: "glob" },
          { effect_type: "replace_text", pattern: "(unclosed", match_type: "regex", replacement: "" }
        ]
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "effects")).to eq(
        [
          "has an invalid or missing effect_type in effect 1", "has an invalid or missing effect_type in effect 2",
          "has an invalid or missing category_id in effect 3", "has an invalid or missing tag_ids in effect 4",
          "has an invalid or missing tag_ids in effect 5", "has an invalid or missing recurrence_type in effect 6",
          "has an invalid or missing recurrence_type in effect 7", "has an invalid or missing replacement in effect 8",
          "has an invalid or missing pattern in effect 8", "has an invalid or missing target_column in effect 9",
          "has an invalid or missing match_type in effect 9", "has an invalid or missing pattern in effect 10"
        ]
      )
      expect(Transaction::Import::Rule::Record.count).to eq(0)
    end

    it "rejects fields that do not belong to the effect type" do
      create_rule(
        name: "Mixed", pattern: "x",
        effects: [
          { effect_type: "set_category", category_id: category.id, pattern: "x", tag_ids: [ tag.id ] },
          { effect_type: "add_tags", tag_ids: [ tag.id ], replacement: "", target_column: "title" },
          { effect_type: "set_recurrence_type", recurrence_type: "recurring", match_type: "regex" },
          { effect_type: "replace_text", pattern: "x", replacement: "", category_id: category.id, recurrence_type: "recurring" }
        ]
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "effects")).to eq(
        [
          "has an unexpected tag_ids in effect 1", "has an unexpected pattern in effect 1",
          "has an unexpected target_column in effect 2",
          "has an unexpected match_type in effect 3",
          "has an unexpected category_id in effect 4", "has an unexpected recurrence_type in effect 4"
        ]
      )
      expect(Transaction::Import::Rule::Record.count).to eq(0)
    end

    it "rejects categories and tags that do not belong to the user" do
      create_rule(
        name: "Foreign", pattern: "x",
        effects: [
          { effect_type: "set_category", category_id: create(:category).id },
          { effect_type: "add_tags", tag_ids: [ tag.id, create(:tag).id ] }
        ]
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "effects")).to eq(
        [ "has an invalid or missing category_id in effect 1", "has an invalid or missing tag_ids in effect 2" ]
      )
      expect(Transaction::Import::Rule::Record.count).to eq(0)
    end

    it "rejects a duplicated name" do
      create(:transaction_import_rule, user:, name: "Delivery")

      create_rule(name: "delivery", pattern: "x", effects: [ { effect_type: "skip" } ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "name")).to be_present
    end

    it "returns 400 without the root key" do
      post "/api/v1/transactions/import_rules", params: {}, headers:, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    context "when unauthenticated" do
      subject { create_rule({ name: "x", pattern: "x" }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "rule ordering" do
    def create_rule(name, position)
      post "/api/v1/transactions/import_rules",
           params: { import_rule: { name:, pattern: name, position:, effects: [ { effect_type: "skip" } ] } },
           headers:, as: :json
    end

    def ordered_names
      Transaction::Import::Rule::Record.where(user_id: user.id).order(:position).pluck(:name)
    end

    def positions
      Transaction::Import::Rule::Record.where(user_id: user.id).order(:position).pluck(:position)
    end

    it "shifts the following rules when a rule is inserted" do
      create_rule("rule1", 0)
      create_rule("rule2", 1)
      create_rule("rule3", 0)
      expect(ordered_names).to eq(%w[rule3 rule1 rule2])

      create_rule("rule4", 3)
      expect(ordered_names).to eq(%w[rule3 rule1 rule2 rule4])

      create_rule("rule5", 1)
      expect(ordered_names).to eq(%w[rule3 rule5 rule1 rule2 rule4])
      expect(positions).to eq([ 0, 1, 2, 3, 4 ])
    end

    it "appends at the end when the position is past the last rule" do
      create_rule("rule1", 0)
      create_rule("rule2", 10)

      expect(ordered_names).to eq(%w[rule1 rule2])
      expect(positions).to eq([ 0, 1 ])
    end

    it "reorders the other rules when a rule is moved" do
      rules = %w[a b c].each_with_index.map { |name, index| create(:transaction_import_rule, user:, name:, position: index) }

      patch "/api/v1/transactions/import_rules/#{rules.last.id}", params: { import_rule: { position: 0 } }, headers:, as: :json

      expect(rule_attributes(response.parsed_body)).to include("position" => 0)
      expect(ordered_names).to eq(%w[c a b])
    end

    it "closes the gap when a rule is deleted" do
      rules = %w[a b c].each_with_index.map { |name, index| create(:transaction_import_rule, user:, name:, position: index) }

      delete "/api/v1/transactions/import_rules/#{rules.first.id}", headers: headers

      expect(ordered_names).to eq(%w[b c])
      expect(positions).to eq([ 0, 1 ])
    end
  end

  describe "PATCH /api/v1/transactions/import_rules/:id" do
    let(:tag) { create(:tag, user:) }
    let(:rule) do
      create(
        :transaction_import_rule, user:, name: "Delivery", pattern: "Ifd",
        effects_attributes: [ { effect_type: "set_category", category_id: create(:category, user:).id }, { effect_type: "replace_text" } ]
      )
    end

    def update_rule(id, params, request_headers = headers)
      patch "/api/v1/transactions/import_rules/#{id}", params: { import_rule: params }, headers: request_headers, as: :json
    end

    it "updates the rule and keeps its effects when they are not sent" do
      update_rule(rule.id, { name: "Food delivery", active: false, position: 0, target_column: "description" })

      expect(response).to have_http_status(:ok)
      expect(rule_attributes(response.parsed_body)).to include(
        "name" => "Food delivery", "active" => false, "position" => 0, "target_column" => "description"
      )
      expect(rule_attributes(response.parsed_body)["effects"].pluck("effect_type")).to eq(%w[set_category replace_text])
    end

    it "replaces all the effects when they are sent" do
      rule

      expect {
        update_rule(rule.id, { effects: [ { effect_type: "add_tags", tag_ids: [ tag.id ] } ] })
      }.to change(Transaction::Import::Rule::Effect::Record, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(rule_attributes(response.parsed_body)["effects"]).to match([ include("effect_type" => "add_tags", "tag_ids" => [ tag.id ]) ])
    end

    it "accepts the effects exactly as they were returned" do
      category = create(:category, user:)
      tag = create(:tag, user:)
      rule = create(
        :transaction_import_rule, user:,
        effects_attributes: [
          { effect_type: "set_category", category_id: category.id }, { effect_type: "add_tags", tag_ids: [ tag.id ] },
          { effect_type: "replace_text", match_type: "regex", pattern: "x+", replacement: "", target_column: "title" }, { effect_type: "skip" }
        ]
      )
      get "/api/v1/transactions/import_rules/#{rule.id}", headers: headers
      effects = rule_attributes(response.parsed_body)["effects"]

      update_rule(rule.id, { name: "Renamed", effects: })

      expect(response).to have_http_status(:ok)
      saved = rule_attributes(response.parsed_body)["effects"]

      expect(saved.map { |effect| effect.except("id") }).to eq(effects.map { |effect| effect.except("id") })
    end

    it "rejects an empty list of effects without touching the current ones" do
      update_rule(rule.id, { effects: [] })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "effects")).to eq([ "can't be blank" ])
      expect(rule.reload.effects.size).to eq(2)
    end

    it "rejects invalid effects without touching the current ones" do
      update_rule(rule.id, { effects: [ { effect_type: "set_category" } ] })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "effects")).to eq([ "has an invalid or missing category_id in effect 1" ])
      expect(rule.reload.effects.size).to eq(2)
    end

    it "keeps the same name for the same rule" do
      update_rule(rule.id, { name: "delivery", pattern: "Ifd*" })

      expect(response).to have_http_status(:ok)
    end

    it "validates the regex against the stored match type" do
      rule.update!(match_type: "regex", pattern: "ok")

      update_rule(rule.id, { pattern: "(unclosed" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "pattern")).to be_present
    end

    it "rejects a name already taken" do
      create(:transaction_import_rule, user:, name: "Other")

      update_rule(rule.id, { name: "other" })

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 for another user's rule" do
      update_rule(create(:transaction_import_rule).id, { name: "x" })

      expect(response).to have_http_status(:not_found)
    end

    context "when unauthenticated" do
      subject { update_rule(rule.id, { name: "x" }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "DELETE /api/v1/transactions/import_rules/:id" do
    let!(:rule) { create(:transaction_import_rule, user:) }

    def destroy_rule(id, request_headers = headers)
      delete "/api/v1/transactions/import_rules/#{id}", headers: request_headers
    end

    it "deletes the rule" do
      expect { destroy_rule(rule.id) }.to change(Transaction::Import::Rule::Record, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["message"]).to eq("Import rule deleted successfully")
    end

    it "returns 404 for another user's rule" do
      other_rule = create(:transaction_import_rule)

      expect { destroy_rule(other_rule.id) }.not_to change(Transaction::Import::Rule::Record, :count)

      expect(response).to have_http_status(:not_found)
    end

    context "when unauthenticated" do
      subject { destroy_rule(rule.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
