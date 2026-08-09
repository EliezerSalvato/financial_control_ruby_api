require "rails_helper"

RSpec.describe Institution::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }

  describe "#list" do
    let!(:active_institution) { create(:institution, user:, name: "Nubank", active: true) }
    let!(:inactive_institution) { create(:institution, :inactive, user:, name: "Archive Bank") }

    it "returns Success with the user's institutions and pagination" do
      result = repository.list(
        user: user_entity,
        filters: {},
        sorting: "active desc, name asc",
        page: 1,
        per_page: 25
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:institutions_listed)
      expect(result.value[:institutions].map(&:id)).to eq([ active_institution.id, inactive_institution.id ])
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
      expect(result.type).to eq(:institutions_listed)
      expect(result.value[:institutions].map(&:id)).to contain_exactly(active_institution.id, inactive_institution.id)
    end
  end

  describe "#find_by_id" do
    it "returns Success when the institution belongs to the user" do
      institution = create(:institution, user:, name: "Nubank")

      result = repository.find_by_id(user: user_entity, id: institution.id)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:institution_found)
      expect(result.value[:institution].id).to eq(institution.id)
    end

    it "returns Failure when the institution belongs to another user" do
      institution = create(:institution)

      result = repository.find_by_id(user: user_entity, id: institution.id)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:institution_not_found)
    end
  end

  describe "#exists?" do
    before { create(:institution, user:, name: "Nubank") }

    it "is case-insensitive for the same user" do
      expect(repository.exists?(user: user_entity, name: "nubank")).to be(true)
    end

    it "ignores the excluded id" do
      institution = Institution::Record.find_by!(user_id: user.id, name: "Nubank")

      expect(repository.exists?(user: user_entity, name: "Nubank", excluding_id: institution.id)).to be(false)
    end

    it "does not match another user's institution" do
      expect(repository.exists?(user: user_entity, name: create(:institution, name: "Other").name)).to be(false)
    end
  end

  describe "#create" do
    it "creates an institution for the user" do
      result = repository.create(
        user: user_entity,
        attributes: { name: "Nubank", logo_key: "institutions/nubank.png", active: true }
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:institution_created)
      expect(result.value[:institution]).to have_attributes(
        name: "Nubank",
        logo_key: "institutions/nubank.png",
        active: true,
        user_id: user.id
      )
    end
  end

  describe "#update" do
    it "updates the institution attributes" do
      institution = Institution::Mapper.to_entity(
        create(:institution, user:, name: "Nubank", logo_key: "institutions/nubank.png", active: true)
      )

      result = repository.update(
        institution:,
        attributes: { name: "Inter", logo_key: "institutions/inter.png", active: false }
      )

      expect(result).to be_a(Solid::Success)
      expect(result.value[:institution]).to have_attributes(
        name: "Inter",
        logo_key: "institutions/inter.png",
        active: false
      )
    end
  end

  describe "#destroy" do
    it "destroys the institution" do
      institution = Institution::Mapper.to_entity(create(:institution, user:))

      expect {
        result = repository.destroy(institution:)

        expect(result).to be_a(Solid::Success)
        expect(result.type).to eq(:institution_destroyed)
      }.to change(Institution::Record, :count).by(-1)
    end
  end
end
