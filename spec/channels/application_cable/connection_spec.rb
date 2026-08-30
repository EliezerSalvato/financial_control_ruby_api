require "rails_helper"

RSpec.describe ApplicationCable::Connection do
  include ActionCable::Connection::TestCase::Behavior
  include AuthHelpers

  let(:user) { create(:user, :verified) }

  it "connects with a token query param" do
    connect params: { token: bearer_token_for(user) }

    expect(connection.current_user).to have_attributes(id: user.id, email: user.email)
  end

  it "connects with an Authorization header" do
    connect headers: { "Authorization" => "Bearer #{bearer_token_for(user)}" }

    expect(connection.current_user.id).to eq(user.id)
  end

  it "rejects a missing token" do
    expect { connect }.to have_rejected_connection
  end

  it "rejects an invalid token" do
    expect { connect params: { token: "invalid-token" } }.to have_rejected_connection
  end

  it "rejects an inactive user" do
    user.update!(active: false)

    expect { connect params: { token: bearer_token_for(user) } }.to have_rejected_connection
  end
end
