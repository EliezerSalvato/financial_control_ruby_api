require "rails_helper"

RSpec.describe Core::Settlement::Processing::FailureNotifying do
  include ActionCable::TestHelper

  let(:user) { create(:user, :verified) }
  let(:month) { 8 }
  let(:year) { 2026 }
  let(:transaction_id) { SecureRandom.uuid }
  let(:credit_card_id) { create(:credit_card, user:).id }

  def notify(failures:, **overrides)
    described_class.call(user_id: user.id, month:, year:, failures:, **overrides)
  end

  it "creates a transaction.validation.errors notification with notifiable and competence" do
    occurred_on = Date.new(2026, 8, 11)
    result = nil

    expect {
      result = notify(
        failures: [
          {
            kind: :occurrence,
            type: :insufficient_account_balance,
            messages: [ "Account balance is insufficient" ],
            transaction_id:,
            description: "Rent",
            occurred_on:
          }
        ]
      )
    }.to change(Notification::Record, :count).by(1)
      .and have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).exactly(:once)

    expect(result).to be_a(Solid::Success)
    notification = Notification::Record.last
    expect(notification).to have_attributes(
      kind: "transaction.validation.errors",
      title: "Error settling transaction Rent in 08/2026",
      body: "Insufficient account balance",
      notifiable_type: "Transaction::Record",
      notifiable_id: transaction_id
    )
    expect(notification.data).to include(
      "type" => "insufficient_account_balance",
      "item_kind" => "occurrence",
      "month" => 8,
      "year" => 2026,
      "occurred_on" => "2026-08-11"
    )
  end

  it "creates a credit_card_invoice.validation.errors notification" do
    due_date = Date.new(2026, 8, 17)

    expect {
      notify(
        failures: [
          {
            kind: :invoice,
            type: :insufficient_account_balance,
            messages: [ "Account balance is insufficient" ],
            credit_card_id:,
            credit_card_name: "Nubank",
            due_date:
          }
        ]
      )
    }.to change(Notification::Record, :count).by(1)

    notification = Notification::Record.last
    expect(notification).to have_attributes(
      kind: "credit_card_invoice.validation.errors",
      title: "Error settling the Nubank card invoice in 08/2026",
      notifiable_type: "CreditCard::Record",
      notifiable_id: credit_card_id
    )
    expect(notification.data).to include("month" => 8, "year" => 2026, "due_date" => "2026-08-17")
  end

  it "uses a generic title when description is missing" do
    notify(
      failures: [
        {
          kind: :occurrence,
          type: :transaction_not_found,
          messages: [],
          occurred_on: Date.new(2026, 8, 11)
        }
      ]
    )

    expect(Notification::Record.last.title).to eq("Error settling a transaction in 08/2026")
  end

  it "uses a generic title when credit_card_name is missing" do
    notify(
      failures: [
        {
          kind: :invoice,
          type: :credit_card_not_found,
          messages: [],
          due_date: Date.new(2026, 8, 17)
        }
      ]
    )

    expect(Notification::Record.last.title).to eq("Error settling a card invoice in 08/2026")
  end

  it "uses the translated type as body instead of the attribute-prefixed messages" do
    notify(
      failures: [
        {
          kind: :occurrence,
          type: :insufficient_account_balance,
          messages: [ "Current balance Insufficient account balance", "Insufficient account balance" ],
          transaction_id:,
          description: "Rent",
          occurred_on: Date.new(2026, 8, 11)
        }
      ]
    )

    expect(Notification::Record.last.body).to eq("Insufficient account balance")
  end

  it "falls back to the messages when the type has no translation" do
    notify(
      failures: [
        {
          kind: :occurrence,
          type: :some_untranslated_type,
          messages: [ "Something went wrong" ],
          transaction_id:,
          description: "Rent",
          occurred_on: Date.new(2026, 8, 11)
        }
      ]
    )

    expect(Notification::Record.last.body).to eq("Something went wrong")
  end

  it "falls back to the type when there is neither a translation nor messages" do
    notify(
      failures: [
        {
          kind: :occurrence,
          type: :some_untranslated_type,
          messages: [],
          transaction_id:,
          description: "Rent",
          occurred_on: Date.new(2026, 8, 11)
        }
      ]
    )

    expect(Notification::Record.last.body).to eq("some_untranslated_type")
  end

  it "skips a duplicate unread notification of the same kind, notifiable, and competence" do
    failure = {
      kind: :occurrence,
      type: :insufficient_account_balance,
      messages: [ "Account balance is insufficient" ],
      transaction_id:,
      description: "Rent",
      occurred_on: Date.new(2026, 8, 11)
    }

    expect { notify(failures: [ failure ]) }.to change(Notification::Record, :count).by(1)
    expect { notify(failures: [ failure ]) }.to change(Notification::Record, :count).by(0)
  end

  it "creates the notification without a notifiable when transaction_id is missing" do
    notify(
      failures: [
        {
          kind: :occurrence,
          type: :transaction_not_found,
          messages: [],
          description: "Rent",
          occurred_on: Date.new(2026, 8, 11)
        }
      ]
    )

    expect(Notification::Record.last).to have_attributes(
      notifiable_type: nil,
      notifiable_id: nil
    )
  end

  it "keeps valid items when another failure has no transaction_id" do
    expect {
      notify(
        failures: [
          {
            kind: :occurrence,
            type: :insufficient_account_balance,
            messages: [ "Account balance is insufficient" ],
            transaction_id:,
            description: "Rent",
            occurred_on: Date.new(2026, 8, 11)
          },
          {
            kind: :occurrence,
            type: :transaction_not_found,
            messages: [],
            description: "Unknown",
            occurred_on: Date.new(2026, 8, 12)
          }
        ]
      )
    }.to change(Notification::Record, :count).by(2)
  end

  it "broadcasts a grouped settlement.errors event" do
    expect {
      notify(
        failures: [
          {
            kind: :occurrence,
            type: :insufficient_account_balance,
            messages: [ "Account balance is insufficient" ],
            transaction_id:,
            description: "Rent",
            occurred_on: Date.new(2026, 8, 11)
          }
        ]
      )
    }.to have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).with { |payload|
      expect(payload[:kind]).to eq("settlement.errors")
      expect(payload).not_to have_key(:notification)
    }
  end

  it "writes the title in pt-BR when the user locale is pt-BR" do
    user.update!(configs: { "locale" => "pt-BR" })

    notify(
      failures: [
        {
          kind: :occurrence,
          type: :insufficient_account_balance,
          messages: [ "Saldo insuficiente" ],
          transaction_id:,
          description: "Aluguel",
          occurred_on: Date.new(2026, 8, 11)
        }
      ]
    )

    expect(Notification::Record.last.title).to eq("Erro ao efetivar a transação Aluguel em 08/2026")
  end
end
