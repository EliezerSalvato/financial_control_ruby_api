require "rails_helper"

RSpec.describe Tag::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }

  describe "#list" do
    let!(:active_tag) { create(:tag, user:, name: "Vacation", active: true) }
    let!(:inactive_tag) { create(:tag, :inactive, user:, name: "Archive") }

    it "returns Success with the user's tags and pagination" do
      result = repository.list(
        user: user_entity,
        filters: {},
        sorting: "active desc, name asc",
        page: 1,
        per_page: 25
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:tags_listed)
      expect(result.value[:tags].map(&:id)).to eq([ active_tag.id, inactive_tag.id ])
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
      expect(result.type).to eq(:tags_listed)
      expect(result.value[:tags].map(&:id)).to contain_exactly(active_tag.id, inactive_tag.id)
    end
  end

  describe "#find_by_id" do
    it "returns Success when the tag belongs to the user" do
      tag = create(:tag, user:, name: "Vacation")

      result = repository.find_by_id(user: user_entity, id: tag.id)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:tag_found)
      expect(result.value[:tag].id).to eq(tag.id)
    end

    it "returns Failure when the tag belongs to another user" do
      tag = create(:tag)

      result = repository.find_by_id(user: user_entity, id: tag.id)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:tag_not_found)
    end
  end

  describe "#find_by_ids" do
    it "returns Success when all tags belong to the user" do
      tag_a = create(:tag, user:, name: "Vacation")
      tag_b = create(:tag, user:, name: "Groceries")

      result = repository.find_by_ids(user: user_entity, ids: [ tag_a.id, tag_b.id ])

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:tags_found)
      expect(result.value[:tags].map(&:id)).to contain_exactly(tag_a.id, tag_b.id)
    end

    it "returns Failure when any tag belongs to another user" do
      own_tag = create(:tag, user:, name: "Vacation")
      other_tag = create(:tag)

      result = repository.find_by_ids(user: user_entity, ids: [ own_tag.id, other_tag.id ])

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:tags_not_found)
    end

    it "returns Failure when any tag is missing" do
      tag = create(:tag, user:, name: "Vacation")

      result = repository.find_by_ids(user: user_entity, ids: [ tag.id, UUID.generate ])

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:tags_not_found)
    end
  end

  describe "#exists?" do
    before { create(:tag, user:, name: "Vacation") }

    it "is case-insensitive for the same user" do
      expect(repository.exists?(user: user_entity, name: "vacation")).to be(true)
    end

    it "ignores the excluded id" do
      tag = Tag::Record.find_by!(user_id: user.id, name: "Vacation")

      expect(repository.exists?(user: user_entity, name: "Vacation", excluding_id: tag.id)).to be(false)
    end

    it "does not match another user's tag" do
      expect(repository.exists?(user: user_entity, name: create(:tag, name: "Other").name)).to be(false)
    end
  end

  describe "#create" do
    it "creates a tag for the user" do
      result = repository.create(user: user_entity, attributes: { name: "Vacation", color: "#3B82F6", active: true })

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:tag_created)
      expect(result.value[:tag]).to have_attributes(name: "Vacation", color: "#3B82F6", active: true, user_id: user.id)
    end
  end

  describe "#update" do
    it "updates the tag attributes" do
      tag = Tag::Mapper.to_entity(create(:tag, user:, name: "Vacation", active: true))

      result = repository.update(tag:, attributes: { name: "Travel", color: "#10B981", active: false })

      expect(result).to be_a(Solid::Success)
      expect(result.value[:tag]).to have_attributes(name: "Travel", color: "#10B981", active: false)
    end
  end

  describe "#destroy" do
    it "destroys the tag" do
      tag = Tag::Mapper.to_entity(create(:tag, user:))

      expect {
        result = repository.destroy(tag:)

        expect(result).to be_a(Solid::Success)
        expect(result.type).to eq(:tag_destroyed)
      }.to change(Tag::Record, :count).by(-1)
    end
  end
end
