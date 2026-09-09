require "rails_helper"

RSpec.describe Core::CreditCard::InvoiceSettlement::EnsureUnpaid do
  subject(:result) do
    described_class.call(
      user: user_entity,
      from:,
      to:,
      payment_method:,
      credit_card_id:
    )
  end

  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }
  let(:account) { create(:account, :bank_account, user:) }
  let(:credit_card) { create(:credit_card, user:, default_payment_account: account, closing_day: 10, due_day: 17) }
  let(:from) { Date.new(2026, 8, 1) }
  let(:to) { Date.new(2026, 8, 1) }
  let(:payment_method) { Core::Transaction::PaymentMethod::CREDIT_CARD }
  let(:credit_card_id) { credit_card.id }

  def pay_invoice(
    card: credit_card,
    opening_date: Date.new(2026, 7, 11),
    closing_date: Date.new(2026, 8, 10),
    due_date: Date.new(2026, 8, 17)
  )
    create(
      :credit_card_invoice_settlement,
      credit_card: card,
      payment_account: card.default_payment_account,
      opening_date:,
      closing_date:,
      due_date:,
      total_value: 100,
      settled_on: due_date
    )
  end

  it "skips the check for an account payment" do
    pay_invoice
    result = described_class.call(
      user: user_entity,
      from:,
      to:,
      payment_method: Core::Transaction::PaymentMethod::PIX,
      credit_card_id: nil
    )

    expect(result).to be_a(Solid::Success)
  end

  it "continues when the card has no paid invoice covering the period" do
    expect(result).to be_a(Solid::Success)
  end

  it "continues when the paid invoice is outside the period" do
    pay_invoice
    result = described_class.call(
      user: user_entity,
      from: Date.new(2026, 8, 11),
      to: Date.new(2026, 8, 11),
      payment_method:,
      credit_card_id:
    )

    expect(result).to be_a(Solid::Success)
  end

  it "returns Failure when starts_on falls in a paid invoice" do
    pay_invoice

    expect(result).to be_a(Solid::Failure)
    expect(result.type).to eq(:invoice_already_paid)
    expect(result.value[:input].errors.details[:base]).to include(error: :invoice_already_paid)
  end

  it "returns Failure when an open-ended range overlaps a later paid invoice" do
    pay_invoice

    result = described_class.call(
      user: user_entity,
      from: Date.new(2026, 7, 5),
      to: nil,
      payment_method:,
      credit_card_id:
    )

    expect(result).to be_a(Solid::Failure)
    expect(result.type).to eq(:invoice_already_paid)
  end

  it "returns credit_card_id not_found for another user's paid invoice instead of invoice_already_paid" do
    other_card = create(:credit_card, closing_day: 10, due_day: 17)
    pay_invoice(card: other_card)

    result = described_class.call(
      user: user_entity,
      from:,
      to:,
      payment_method:,
      credit_card_id: other_card.id
    )

    expect(result).to be_a(Solid::Failure)
    expect(result.type).to eq(:invalid_input)
    expect(result.value[:input].errors.details[:credit_card_id]).to include(error: :not_found)
    expect(result.value[:input].errors.details[:base]).not_to include(error: :invoice_already_paid)
  end
end
