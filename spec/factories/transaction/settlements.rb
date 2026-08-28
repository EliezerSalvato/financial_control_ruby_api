FactoryBot.define do
  factory :transaction_settlement, class: "Transaction::Settlement::Record" do
    financial_transaction { association :transaction }
    occurred_on { Date.new(2026, 8, 11) }
    settled_on { Date.new(2026, 8, 11) }
    value { 100 }
    installment_number { nil }

    trait :for_account do
      after(:create) do |settlement|
        account = settlement.financial_transaction.for_account&.account ||
                  create(:account, user: settlement.financial_transaction.user)

        create(:transaction_settlement_for_account, transaction_settlement: settlement, account:)
      end
    end

    trait :for_transfer do
      financial_transaction { association :transaction, :transfer }

      after(:create) do |settlement|
        transfer = settlement.financial_transaction.for_transfer_between_accounts

        create(
          :transaction_settlement_for_transfer_between_accounts,
          transaction_settlement: settlement,
          source_account: transfer&.source_account || create(:account, user: settlement.financial_transaction.user),
          destination_account: transfer&.destination_account || create(:account, user: settlement.financial_transaction.user)
        )
      end
    end

    trait :for_credit_card do
      financial_transaction { association :transaction, :with_credit_card }

      after(:create) do |settlement|
        create(:transaction_settlement_for_credit_card, transaction_settlement: settlement)
      end
    end
  end

  factory :transaction_settlement_for_account, class: "Transaction::Settlement::ForAccount::Record" do
    transaction_settlement { association :transaction_settlement }
    account { association :account, user: transaction_settlement.financial_transaction.user }
  end

  factory :transaction_settlement_for_transfer_between_accounts, class: "Transaction::Settlement::ForTransferBetweenAccounts::Record" do
    transaction_settlement { association :transaction_settlement }
    source_account { association :account, user: transaction_settlement.financial_transaction.user }
    destination_account { association :account, user: transaction_settlement.financial_transaction.user }
  end

  factory :transaction_settlement_for_credit_card, class: "Transaction::Settlement::ForCreditCard::Record" do
    transaction_settlement { association :transaction_settlement }
    limit_consumed { 100 }
    credit_card_invoice_settlement { nil }
  end
end
