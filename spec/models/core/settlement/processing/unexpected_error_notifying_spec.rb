require "rails_helper"

RSpec.describe Core::Settlement::Processing::UnexpectedErrorNotifying do
  let(:user) { create(:user, :verified) }
  let(:month) { 8 }
  let(:year) { 2026 }

  def notify(**overrides)
    described_class.call(user_id: user.id, month:, year:, type: :unexpected, error: "StandardError", **overrides)
  end

  it "creates a settlement.errors notification with competence" do
    result = nil

    expect { result = notify }.to change(Notification::Record, :count).by(1)

    expect(result).to be_a(Solid::Success)
    notification = Notification::Record.last
    expect(notification).to have_attributes(
      kind: "settlement.errors",
      title: "Error settling transactions in 08/2026",
      body: "An unexpected error occurred",
      notifiable_type: nil,
      notifiable_id: nil
    )
    expect(notification.data).to eq(
      "type" => "unexpected",
      "month" => 8,
      "year" => 2026,
      "error" => "StandardError"
    )
  end

  it "skips a duplicate unread notification for the same month, year, and type" do
    expect { notify }.to change(Notification::Record, :count).by(1)
    expect { notify(error: "RuntimeError") }.to change(Notification::Record, :count).by(0)
  end

  it "does not skip an unread error for a different competence" do
    expect { notify(month: 7) }.to change(Notification::Record, :count).by(1)
    expect { notify(month: 8) }.to change(Notification::Record, :count).by(1)
  end

  it "does not skip an unread error of a different type for the same competence" do
    expect { notify }.to change(Notification::Record, :count).by(1)
    expect { notify(type: :previous_month_open) }.to change(Notification::Record, :count).by(1)
  end

  it "omits error from data when error is blank" do
    notify(error: nil)

    expect(Notification::Record.last.body).to eq("An unexpected error occurred")
    expect(Notification::Record.last.data).not_to have_key("error")
  end

  it "writes the title in pt-BR when the user locale is pt-BR" do
    user.update!(configs: { "locale" => "pt-BR" })

    notify

    expect(Notification::Record.last.title).to eq("Erro ao efetivar transações em 08/2026")
    expect(Notification::Record.last.body).to eq("Ocorreu um erro inesperado")
  end
end
