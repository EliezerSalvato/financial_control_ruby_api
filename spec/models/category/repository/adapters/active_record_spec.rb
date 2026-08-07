require "rails_helper"

RSpec.describe Category::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }

  describe "#list" do
    let!(:active_category) { create(:category, user:, name: "Vacation", active: true) }
    let!(:inactive_category) { create(:category, :inactive, user:, name: "Archive") }

    it "returns Success with the user's categories and pagination" do
      result = repository.list(
        user: user_entity,
        filters: {},
        sorting: "active desc, name asc",
        page: 1,
        per_page: 25
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:categories_listed)
      expect(result.value[:categories].map(&:id)).to eq([ active_category.id, inactive_category.id ])
      expect(result.value[:pagination]).to have_attributes(page: 1, per_page: 25, count: 2)
    end

    it "ignores unknown filters" do
      result = repository.list(
        user: user_entity,
        filters: { unknown_field_eq: "x" },
        sorting: "name asc",
        page: 1,
        per_page: 25
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:categories_listed)
      expect(result.value[:categories].map(&:id)).to contain_exactly(active_category.id, inactive_category.id)
    end
  end

  describe "#find_by_id" do
    it "returns Success when the category belongs to the user" do
      category = create(:category, user:, name: "Vacation")

      result = repository.find_by_id(user: user_entity, id: category.id)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:category_found)
      expect(result.value[:category].id).to eq(category.id)
    end

    it "returns Failure when the category belongs to another user" do
      category = create(:category)

      result = repository.find_by_id(user: user_entity, id: category.id)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:category_not_found)
    end
  end

  describe "#exists?" do
    before { create(:category, user:, name: "Vacation") }

    it "is case-insensitive for the same user" do
      expect(repository.exists?(user: user_entity, name: "vacation")).to be(true)
    end

    it "ignores the excluded id" do
      category = Category::Record.find_by!(user_id: user.id, name: "Vacation")

      expect(repository.exists?(user: user_entity, name: "Vacation", excluding_id: category.id)).to be(false)
    end

    it "does not match another user's category" do
      expect(repository.exists?(user: user_entity, name: create(:category, name: "Other").name)).to be(false)
    end
  end

  describe "#create" do
    it "creates a category for the user" do
      result = repository.create(user: user_entity, attributes: { name: "Vacation", color: "#3B82F6", active: true })

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:category_created)
      expect(result.value[:category]).to have_attributes(name: "Vacation", color: "#3B82F6", active: true, user_id: user.id)
    end
  end

  describe "#update" do
    it "updates the category attributes" do
      category = Category::Mapper.to_entity(create(:category, user:, name: "Vacation", active: true))

      result = repository.update(category:, attributes: { name: "Travel", color: "#10B981", active: false })

      expect(result).to be_a(Solid::Success)
      expect(result.value[:category]).to have_attributes(name: "Travel", color: "#10B981", active: false)
    end
  end

  describe "#destroy" do
    it "destroys the category" do
      category = Category::Mapper.to_entity(create(:category, user:))

      expect {
        result = repository.destroy(category:)

        expect(result).to be_a(Solid::Success)
        expect(result.type).to eq(:category_destroyed)
      }.to change(Category::Record, :count).by(-1)
    end
  end
end
