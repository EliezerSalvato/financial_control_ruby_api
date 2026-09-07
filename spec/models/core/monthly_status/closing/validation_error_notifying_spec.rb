require "rails_helper"

RSpec.describe Core::MonthlyStatus::Closing::ValidationErrorNotifying do
  include ActionCable::TestHelper

  let(:user) { create(:user, :verified) }
  let(:monthly_status) { create(:monthly_status, user:, month: 8, year: 2026) }

  def notify(pending:)
    described_class.call(user_id: user.id, pending:)
  end

  it "creates a monthly_status.closing.errors notification per pending month" do
    pending_occurrences = [ { transaction_id: SecureRandom.uuid, occurred_on: Date.new(2026, 8, 11), description: "Rent" } ]
    pending_invoices = [ { credit_card_id: SecureRandom.uuid, due_date: Date.new(2026, 8, 17) } ]
    result = nil

    expect {
      result = notify(
        pending: [
          {
            month: 8,
            year: 2026,
            monthly_status_id: monthly_status.id,
            pending_occurrences:,
            pending_invoices:
          }
        ]
      )
    }.to change(Notification::Record, :count).by(1)
      .and have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).exactly(:once)

    expect(result).to be_a(Solid::Success)
    notification = Notification::Record.last
    expect(notification).to have_attributes(
      kind: "monthly_status.closing.errors",
      title: "Error closing month 08/2026",
      body: "Pending transactions: Rent. Pending invoices: 1.",
      notifiable_type: "MonthlyStatus::Record",
      notifiable_id: monthly_status.id
    )
    expect(notification.data).to include("month" => 8, "year" => 2026)
  end

  it "uses the translated failure type as body when the month failed to close" do
    notify(
      pending: [
        { month: 8, year: 2026, monthly_status_id: monthly_status.id, failure: :monthly_status_closing_failed }
      ]
    )

    expect(Notification::Record.last.body).to eq("Monthly status closing failed")
  end

  it "skips a duplicate unread notification for the same month and year" do
    pending = [ { month: 8, year: 2026, monthly_status_id: monthly_status.id, failure: :monthly_status_closing_failed } ]

    expect { notify(pending:) }.to change(Notification::Record, :count).by(1)
    expect { notify(pending:) }.to change(Notification::Record, :count).by(0)
  end

  it "rejects pending items that are missing month or year" do
    result = notify(pending: [ { failure: :monthly_status_not_found } ])

    expect(result).to be_a(Solid::Failure)
    expect(result.type).to eq(:invalid_input)
    expect(result.value[:input].errors[:pending]).to be_present
    expect(Notification::Record.count).to eq(0)
  end

  it "creates the notification without a notifiable when monthly_status_id is missing" do
    notify(pending: [ { month: 8, year: 2026, failure: :monthly_status_not_found } ])

    expect(Notification::Record.last).to have_attributes(
      notifiable_type: nil,
      notifiable_id: nil
    )
  end

  it "keeps valid items when another pending month has no monthly_status_id" do
    expect {
      notify(
        pending: [
          { month: 8, year: 2026, monthly_status_id: monthly_status.id, failure: :monthly_status_closing_failed },
          { month: 7, year: 2026, failure: :monthly_status_not_found }
        ]
      )
    }.to change(Notification::Record, :count).by(2)
  end

  it "broadcasts a grouped monthly_status.errors event" do
    expect {
      notify(pending: [ { month: 8, year: 2026, monthly_status_id: monthly_status.id, failure: :monthly_status_not_found } ])
    }.to have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).with { |payload|
      expect(payload[:kind]).to eq("monthly_status.errors")
    }
  end

  it "writes the title in pt-BR when the user locale is pt-BR" do
    user.update!(configs: { "locale" => "pt-BR" })

    notify(pending: [ { month: 8, year: 2026, monthly_status_id: monthly_status.id, failure: :monthly_status_closing_failed } ])

    expect(Notification::Record.last.title).to eq("Erro ao fechar o mês 08/2026")
    expect(Notification::Record.last.body).to eq("Falha ao fechar o status mensal")
  end
end
