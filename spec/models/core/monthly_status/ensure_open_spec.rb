require "rails_helper"

RSpec.describe Core::MonthlyStatus::EnsureOpen do
  subject(:result) do
    described_class.call(
      user: user_entity,
      date:,
      payment_method:,
      credit_card_id:
    )
  end

  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }
  let(:date) { Date.new(2026, 8, 28) }
  let(:payment_method) { Core::Transaction::PaymentMethod::PIX }
  let(:credit_card_id) { nil }

  describe "reference month" do
    it "uses the civil month of date for an account payment" do
      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_status_is_open)
      expect(result.value[:reference_month]).to have_attributes(month: 8, year: 2026)
    end

    it "uses the civil month of date for a transfer" do
      result = described_class.call(user: user_entity, date:, payment_method: nil, credit_card_id: nil)

      expect(result).to be_a(Solid::Success)
      expect(result.value[:reference_month]).to have_attributes(month: 8, year: 2026)
    end

    it "resolves a 28/08 purchase to month 10 when closing_day is after due_day" do
      credit_card = create(:credit_card, user:, closing_day: 25, due_day: 10)

      result = described_class.call(
        user: user_entity,
        date: Date.new(2026, 8, 28),
        payment_method: Core::Transaction::PaymentMethod::CREDIT_CARD,
        credit_card_id: credit_card.id
      )

      expect(result).to be_a(Solid::Success)
      expect(result.value[:reference_month]).to have_attributes(month: 10, year: 2026)
    end

    it "resolves a 28/08 purchase to month 09 when closing_day is before due_day" do
      credit_card = create(:credit_card, user:, closing_day: 10, due_day: 17)

      result = described_class.call(
        user: user_entity,
        date: Date.new(2026, 8, 28),
        payment_method: Core::Transaction::PaymentMethod::CREDIT_CARD,
        credit_card_id: credit_card.id
      )

      expect(result).to be_a(Solid::Success)
      expect(result.value[:reference_month]).to have_attributes(month: 9, year: 2026)
    end

    it "resolves a 02/08 purchase to month 08 when closing_day is before due_day" do
      credit_card = create(:credit_card, user:, closing_day: 10, due_day: 17)

      result = described_class.call(
        user: user_entity,
        date: Date.new(2026, 8, 2),
        payment_method: Core::Transaction::PaymentMethod::CREDIT_CARD,
        credit_card_id: credit_card.id
      )

      expect(result).to be_a(Solid::Success)
      expect(result.value[:reference_month]).to have_attributes(month: 8, year: 2026)
    end
  end

  describe "find or create" do
    it "creates an open row when missing and continues" do
      expect { result }.to change(MonthlyStatus::Record, :count).by(1)

      expect(result).to be_a(Solid::Success)
      expect(result.value[:monthly_status]).to have_attributes(
        month: 8,
        year: 2026,
        status: Core::MonthlyStatus::Status::OPEN
      )
    end

    it "does not create a month that precedes a closed month" do
      create(:monthly_status, :closed, user:, month: 9, year: 2026)

      expect { result }.not_to change(MonthlyStatus::Record, :count)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:later_month_closed)
      expect(result.value[:input].errors.details[:base]).to include(error: :later_month_closed)
    end
  end

  describe "closed month" do
    before { create(:monthly_status, :closed, user:, month: 8, year: 2026) }

    it "returns Failure with the error on base" do
      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:monthly_status_closed)
      expect(result.value[:input].errors.details[:base]).to include(error: :monthly_status_closed)
    end
  end

  describe "credit card ownership" do
    it "adds not_found on credit_card_id when the card belongs to another user" do
      credit_card = create(:credit_card)

      result = described_class.call(
        user: user_entity,
        date:,
        payment_method: Core::Transaction::PaymentMethod::CREDIT_CARD,
        credit_card_id: credit_card.id
      )

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:invalid_input)
      expect(result.value[:input].errors.details[:credit_card_id]).to include(error: :not_found)
    end
  end
end
