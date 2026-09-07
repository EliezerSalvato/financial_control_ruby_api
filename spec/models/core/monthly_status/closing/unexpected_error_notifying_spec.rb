require "rails_helper"

RSpec.describe Core::MonthlyStatus::Closing::UnexpectedErrorNotifying do
  let(:user) { create(:user, :verified) }

  def notify(**overrides)
    described_class.call(user_id: user.id, type: :unexpected, error: "StandardError", **overrides)
  end

  it "creates a monthly_status.errors notification without competence" do
    result = nil

    expect { result = notify }.to change(Notification::Record, :count).by(1)

    expect(result).to be_a(Solid::Success)
    notification = Notification::Record.last
    expect(notification).to have_attributes(
      kind: "monthly_status.errors",
      title: "Error during monthly closing",
      body: "An unexpected error occurred",
      notifiable_type: nil,
      notifiable_id: nil
    )
    expect(notification.data).to eq("type" => "unexpected", "error" => "StandardError")
  end

  it "includes competence in the title, data, and dedup when month and year are given" do
    result = nil

    expect { result = notify(month: 8, year: 2026) }.to change(Notification::Record, :count).by(1)

    expect(result).to be_a(Solid::Success)
    notification = Notification::Record.last
    expect(notification.title).to eq("Error during monthly closing of 08/2026")
    expect(notification.data).to eq("type" => "unexpected", "error" => "StandardError", "month" => 8, "year" => 2026)
  end

  it "skips a duplicate unread notification of the same kind and type" do
    expect { notify }.to change(Notification::Record, :count).by(1)
    expect { notify(error: "RuntimeError") }.to change(Notification::Record, :count).by(0)
  end

  it "skips a duplicate unread notification for the same competence" do
    expect { notify(month: 8, year: 2026) }.to change(Notification::Record, :count).by(1)
    expect { notify(month: 8, year: 2026, error: "RuntimeError") }.to change(Notification::Record, :count).by(0)
  end

  it "does not skip an unread error for a different competence" do
    expect { notify(month: 7, year: 2026) }.to change(Notification::Record, :count).by(1)
    expect { notify(month: 8, year: 2026) }.to change(Notification::Record, :count).by(1)
  end

  it "does not skip an unread error of a different type for the same competence" do
    expect { notify(month: 8, year: 2026) }.to change(Notification::Record, :count).by(1)
    expect { notify(month: 8, year: 2026, type: :monthly_status_not_found) }.to change(Notification::Record, :count).by(1)
  end

  it "omits error from data when error is blank" do
    notify(error: nil)

    expect(Notification::Record.last.body).to eq("An unexpected error occurred")
    expect(Notification::Record.last.data).not_to have_key("error")
  end

  it "writes the title in pt-BR when the user locale is pt-BR" do
    user.update!(configs: { "locale" => "pt-BR" })

    notify

    expect(Notification::Record.last.title).to eq("Erro no fechamento mensal")
    expect(Notification::Record.last.body).to eq("Ocorreu um erro inesperado")
  end
end
