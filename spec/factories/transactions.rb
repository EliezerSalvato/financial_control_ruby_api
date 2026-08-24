FactoryBot.define do
  factory :transaction, class: "Transaction::Record" do
    user
    category { association :category, user: }
    sequence(:description) { |n| "Transaction #{n}" }
    kind { "expense" }
    payment_method { "pix" }
    recurrence_type { "one_time" }
    installments_count { nil }
    ends_on { nil }

    transient do
      with_links { true }
      account { nil }
      credit_card { nil }
      limit_consumption_type { "upfront" }
      source_account { nil }
      destination_account { nil }
      starts_on { Date.new(2026, 8, 11) }
      value { 100 }
      tags { [] }
    end

    after(:create) do |transaction, evaluator|
      next unless evaluator.with_links

      case transaction.kind
      when "transfer_between_accounts"
        Transaction::ForTransferBetweenAccounts::Record.create!(
          financial_transaction: transaction,
          source_account: evaluator.source_account || create(:account, user: transaction.user),
          destination_account: evaluator.destination_account || create(:account, user: transaction.user)
        )
      else
        case transaction.payment_method
        when "credit_card"
          Transaction::ForCreditCard::Record.create!(
            financial_transaction: transaction,
            credit_card: evaluator.credit_card || create(:credit_card, user: transaction.user),
            limit_consumption_type: evaluator.limit_consumption_type
          )
        else
          Transaction::ForAccount::Record.create!(
            financial_transaction: transaction,
            account: evaluator.account || create(:account, user: transaction.user)
          )
        end
      end

      Transaction::Recurrence::Record.create!(
        financial_transaction: transaction,
        starts_on: evaluator.starts_on,
        value: evaluator.value
      )

      Array(evaluator.tags).each do |tag|
        Transaction::Tagging::Record.create!(financial_transaction: transaction, tag:)
      end
    end

    trait :income do
      kind { "income" }
      payment_method { "pix" }
    end

    trait :transfer do
      kind { "transfer_between_accounts" }
      payment_method { nil }
    end

    trait :installment do
      recurrence_type { "installment" }
      installments_count { 2 }
      ends_on { Date.new(2026, 9, 11) }
    end

    trait :recurring do
      recurrence_type { "recurring" }
      installments_count { nil }
      ends_on { nil }
    end

    trait :with_credit_card do
      payment_method { "credit_card" }
    end

    trait :active do
      status { "active" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :canceled do
      status { "canceled" }
      canceled_on { Date.current }
    end
  end

  factory :transaction_for_credit_card, class: "Transaction::ForCreditCard::Record" do
    financial_transaction { association :transaction, :with_credit_card, with_links: false }
    credit_card { association :credit_card, user: financial_transaction.user }
    limit_consumption_type { "upfront" }
  end

  factory :transaction_for_account, class: "Transaction::ForAccount::Record" do
    financial_transaction { association :transaction, with_links: false }
    account { association :account, user: financial_transaction.user }
  end

  factory :transaction_for_transfer_between_accounts, class: "Transaction::ForTransferBetweenAccounts::Record" do
    financial_transaction { association :transaction, :transfer, with_links: false }
    source_account { association :account, user: financial_transaction.user }
    destination_account { association :account, user: financial_transaction.user }
  end

  factory :transaction_recurrence, class: "Transaction::Recurrence::Record" do
    financial_transaction { association :transaction, with_links: false }
    starts_on { Date.new(2026, 8, 11) }
    value { 100 }
  end

  factory :transaction_tagging, class: "Transaction::Tagging::Record" do
    financial_transaction { association :transaction, with_links: false }
    tag { association :tag, user: financial_transaction.user }
  end
end
