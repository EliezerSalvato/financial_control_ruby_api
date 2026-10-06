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

  describe "#find_all_by_names" do
    it "returns the existing tags ignoring the case, scoped to the user" do
      fun = create(:tag, user:, name: "Fun")
      create(:tag, name: "Fun")

      expect(repository.find_all_by_names(user: user_entity, names: %w[fun missing]).value[:tags].map(&:id)).to eq([ fun.id ])
      expect(repository.find_all_by_names(user: user_entity, names: []).value[:tags]).to eq([])
    end
  end

  describe "#find_or_create_by_names" do
    it "reuses the existing tags and creates the missing ones" do
      fun = create(:tag, user:, name: "Fun")

      result = repository.find_or_create_by_names(user: user_entity, names: %w[FUN Daily daily], color: "#111111")

      expect(result.value[:tags].map(&:name)).to contain_exactly("Fun", "Daily")
      expect(result.value[:tags].map(&:id)).to include(fun.id)
      expect(Tag::Record.where(user_id: user.id).count).to eq(2)
    end

    it "returns the tag created by a concurrent job" do
      existing = create(:tag, user:, name: "Daily")
      allow(repository).to receive(:find_records_by_names).and_return([], [ existing ])
      allow(Tag::Record).to receive(:transaction).and_raise(ActiveRecord::RecordNotUnique)

      result = repository.find_or_create_by_names(user: user_entity, names: [ "Daily" ], color: "#111111")

      expect(result.value[:tags].map(&:id)).to eq([ existing.id ])
    end

    it "returns Failure when a tag does not persist" do
      allow_any_instance_of(Tag::Record).to receive(:save).and_return(false)

      expect(repository.find_or_create_by_names(user: user_entity, names: [ "Daily" ], color: "#111111").type).to eq(:tag_creation_failed)
    end
  end
end
