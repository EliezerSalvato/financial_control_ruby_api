require "rails_helper"

RSpec.describe MonthlyStatus::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }

  describe "#find" do
    it "returns the existing monthly status" do
      existing = create(:monthly_status, :closed, user:, month: 8, year: 2026)

      result = repository.find(user_id: user.id, month: 8, year: 2026)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_status_found)
      expect(result.value[:monthly_status]).to have_attributes(
        id: existing.id,
        user_id: user.id,
        month: 8,
        year: 2026,
        status: Core::MonthlyStatus::Status::CLOSED
      )
    end

    it "returns Failure when the row is missing" do
      expect {
        result = repository.find(user_id: user.id, month: 8, year: 2026)

        expect(result).to be_a(Solid::Failure)
        expect(result.type).to eq(:monthly_status_not_found)
      }.not_to change(MonthlyStatus::Record, :count)
    end

    it "is isolated by user_id" do
      other_user = create(:user, :verified)
      create(:monthly_status, :closed, user: other_user, month: 8, year: 2026)

      result = repository.find(user_id: user.id, month: 8, year: 2026)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:monthly_status_not_found)
    end
  end

  describe "#find_or_create" do
    it "creates an open monthly status when the row is missing" do
      expect {
        result = repository.find_or_create(user_id: user.id, month: 8, year: 2026)

        expect(result).to be_a(Solid::Success)
        expect(result.type).to eq(:monthly_status_found)
        expect(result.value[:monthly_status]).to have_attributes(
          user_id: user.id,
          month: 8,
          year: 2026,
          status: Core::MonthlyStatus::Status::OPEN
        )
      }.to change(MonthlyStatus::Record, :count).by(1)
    end

    it "returns the existing row on a second call" do
      existing = create(:monthly_status, :closed, user:, month: 8, year: 2026)

      expect {
        result = repository.find_or_create(user_id: user.id, month: 8, year: 2026)

        expect(result).to be_a(Solid::Success)
        expect(result.value[:monthly_status]).to have_attributes(
          id: existing.id,
          status: Core::MonthlyStatus::Status::CLOSED
        )
      }.not_to change(MonthlyStatus::Record, :count)
    end

    it "is isolated by user_id" do
      other_user = create(:user, :verified)
      create(:monthly_status, :closed, user: other_user, month: 8, year: 2026)

      result = repository.find_or_create(user_id: user.id, month: 8, year: 2026)

      expect(result.value[:monthly_status]).to have_attributes(
        user_id: user.id,
        status: Core::MonthlyStatus::Status::OPEN
      )
      expect(MonthlyStatus::Record.where(user_id: other_user.id, month: 8, year: 2026).sole.status).to eq("closed")
    end
  end

  describe "#update" do
    it "changes the status and returns the entity" do
      monthly_status = MonthlyStatus::Mapper.to_entity(create(:monthly_status, user:, month: 8, year: 2026))

      result = repository.update(monthly_status:, attributes: { status: Core::MonthlyStatus::Status::CLOSED })

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_status_updated)
      expect(result.value[:monthly_status]).to have_attributes(status: Core::MonthlyStatus::Status::CLOSED)
      expect(MonthlyStatus::Record.find(monthly_status.id).status).to eq("closed")
    end

    it "returns Failure when persistence fails" do
      monthly_status = MonthlyStatus::Mapper.to_entity(create(:monthly_status, user:))
      record = MonthlyStatus::Record.find(monthly_status.id)
      errors = ActiveModel::Errors.new(record)
      errors.add(:status, :invalid)

      allow(MonthlyStatus::Mapper).to receive(:to_record).and_return(record)
      allow(record).to receive_messages(update: false, errors:)

      result = repository.update(monthly_status:, attributes: { status: Core::MonthlyStatus::Status::CLOSED })

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:monthly_status_update_failed)
      expect(result.value[:errors]).to be_a(Core::Errors)
    end
  end
end
