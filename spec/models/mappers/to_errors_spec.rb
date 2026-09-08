require "rails_helper"

RSpec.describe "Mapper#to_errors" do
  [
    Account::Mapper,
    Category::Mapper,
    CreditCard::Mapper,
    CreditCard::InvoiceSettlement::Mapper,
    Institution::Mapper,
    Notification::Mapper,
    Tag::Mapper,
    Transaction::Mapper,
    Transaction::ForAccount::Mapper,
    Transaction::ForCreditCard::Mapper,
    Transaction::ForTransferBetweenAccounts::Mapper,
    Transaction::Recurrence::Mapper,
    Transaction::Settlement::Mapper,
    Transaction::Settlement::ForAccount::Mapper,
    Transaction::Settlement::ForCreditCard::Mapper,
    Transaction::Settlement::ForTransferBetweenAccounts::Mapper,
    Transaction::Tagging::Mapper,
    User::Mapper,
    User::Email::Confirmation::Mapper,
    User::Password::Reset::Mapper,
    User::Session::Mapper
  ].each do |mapper|
    it "wraps #{mapper} record errors" do
      record = Struct.new(:errors).new(Struct.new(:messages).new({ name: [ "is invalid" ] }))

      expect(mapper.to_errors(record).messages).to eq(name: [ "is invalid" ])
    end
  end
end
