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

    it "updates processing and last_processed_at without changing status" do
      monthly_status = MonthlyStatus::Mapper.to_entity(create(:monthly_status, user:, month: 8, year: 2026))
      processed_at = Time.zone.parse("2026-08-29 12:00:00")

      result = repository.update(
        monthly_status:,
        attributes: { processing: false, last_processed_at: processed_at }
      )

      expect(result).to be_a(Solid::Success)
      expect(result.value[:monthly_status]).to have_attributes(
        processing: false,
        last_processed_at: processed_at,
        status: Core::MonthlyStatus::Status::OPEN
      )
      record = MonthlyStatus::Record.find(monthly_status.id)
      expect(record.processing).to eq(false)
      expect(record.last_processed_at).to eq(processed_at)
      expect(record.status).to eq("open")
    end

    it "sets processing to true" do
      monthly_status = MonthlyStatus::Mapper.to_entity(create(:monthly_status, user:, month: 8, year: 2026))

      result = repository.update(monthly_status:, attributes: { processing: true })

      expect(result).to be_a(Solid::Success)
      expect(result.value[:monthly_status].processing).to eq(true)
      expect(MonthlyStatus::Record.find(monthly_status.id).processing).to eq(true)
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

  describe "#list_open" do
    it "returns the current and previous months, ignores closed and future months, and is ordered" do
      other_user = create(:user, :verified)
      previous = create(:monthly_status, user:, month: 7, year: 2026)
      current = create(:monthly_status, user:, month: 8, year: 2026)
      other_current = create(:monthly_status, user: other_user, month: 8, year: 2026)
      create(:monthly_status, :closed, user:, month: 6, year: 2026)
      create(:monthly_status, user:, month: 9, year: 2026)

      result = repository.list_open(up_to_month: 8, up_to_year: 2026)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_statuses_listed)
      expect(result.value[:monthly_statuses].map { |monthly_status| [ monthly_status.user_id, monthly_status.year, monthly_status.month ] }).to eq(
        [
          [ other_user.id, 2026, 8 ],
          [ user.id, 2026, 7 ],
          [ user.id, 2026, 8 ]
        ].sort_by { |user_id, year, month| [ user_id, year, month ] }
      )
      expect(result.value[:monthly_statuses].map(&:id)).to contain_exactly(previous.id, current.id, other_current.id)
    end
  end

  describe "#exists_closed_after?" do
    it "returns true when a later month is closed" do
      create(:monthly_status, :closed, user:, month: 9, year: 2026)

      expect(repository.exists_closed_after?(user_id: user.id, month: 8, year: 2026)).to be(true)
    end

    it "returns true when a later month in the next year is closed" do
      create(:monthly_status, :closed, user:, month: 1, year: 2026)

      expect(repository.exists_closed_after?(user_id: user.id, month: 12, year: 2025)).to be(true)
    end

    it "returns false when only earlier months are closed" do
      create(:monthly_status, :closed, user:, month: 7, year: 2026)

      expect(repository.exists_closed_after?(user_id: user.id, month: 8, year: 2026)).to be(false)
    end

    it "returns false when later months are open" do
      create(:monthly_status, user:, month: 9, year: 2026)

      expect(repository.exists_closed_after?(user_id: user.id, month: 8, year: 2026)).to be(false)
    end

    it "returns false when the month itself is closed and no later month is closed" do
      create(:monthly_status, :closed, user:, month: 8, year: 2026)

      expect(repository.exists_closed_after?(user_id: user.id, month: 8, year: 2026)).to be(false)
    end

    it "is isolated by user_id" do
      other_user = create(:user, :verified)
      create(:monthly_status, :closed, user: other_user, month: 9, year: 2026)

      expect(repository.exists_closed_after?(user_id: user.id, month: 8, year: 2026)).to be(false)
    end
  end
end
