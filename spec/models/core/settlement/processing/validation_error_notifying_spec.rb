require "rails_helper"

RSpec.describe Core::Settlement::Processing::ValidationErrorNotifying do
  let(:user) { create(:user, :verified) }
  let(:month) { 8 }
  let(:year) { 2026 }

  def notify(**overrides)
    described_class.call(user_id: user.id, month:, year:, type: :previous_month_open, **overrides)
  end

  it "creates a settlement.errors notification with competence" do
    result = nil

    expect {
      result = notify(messages: [ "The previous month must be closed before processing this month" ])
    }.to change(Notification::Record, :count).by(1)

    expect(result).to be_a(Solid::Success)
    notification = Notification::Record.last
    expect(notification).to have_attributes(
      kind: "settlement.errors",
      title: "Error settling transactions in 08/2026",
      body: "The previous month must be closed before processing this month",
      notifiable_type: nil,
      notifiable_id: nil
    )
    expect(notification.data).to eq("type" => "previous_month_open", "month" => 8, "year" => 2026)
  end

  it "uses the translated type as body when messages are empty" do
    notify

    expect(Notification::Record.last.body).to eq("The previous month must be closed before processing this month")
  end

  it "skips a duplicate unread notification for the same month, year, and type" do
    expect { notify }.to change(Notification::Record, :count).by(1)
    expect { notify }.to change(Notification::Record, :count).by(0)
  end

  it "does not skip an unread error of a different type for the same competence" do
    expect { notify }.to change(Notification::Record, :count).by(1)
    expect { notify(type: :later_month_closed) }.to change(Notification::Record, :count).by(1)
  end

  it "writes the title in pt-BR when the user locale is pt-BR" do
    user.update!(configs: { "locale" => "pt-BR" })

    notify

    expect(Notification::Record.last.title).to eq("Erro ao efetivar transações em 08/2026")
    expect(Notification::Record.last.body).to eq("O mês anterior precisa estar fechado antes de processar este mês")
  end
end
