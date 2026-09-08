require "rails_helper"

RSpec.describe Core::Transaction::PaymentMethod do
  def errors_for(kind:, payment_method:)
    input = Core::Transaction::Creation::Input.new
    described_class.validate_compatibility_with_kind(input.errors, kind:, payment_method:)
    input.errors
  end

  it "requires a payment method for income" do
    expect(errors_for(kind: Core::Transaction::Kind::INCOME, payment_method: nil).details[:payment_method]).to be_present
  end

  it "requires a payment method for expense" do
    expect(errors_for(kind: Core::Transaction::Kind::EXPENSE, payment_method: "").details[:payment_method]).to be_present
  end

  it "rejects a payment method that is not valid for expense" do
    expect(errors_for(kind: Core::Transaction::Kind::EXPENSE, payment_method: "unknown").details[:payment_method]).to be_present
  end
end
