require "rails_helper"

RSpec.describe TransactionImportChannel, type: :channel do
  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }

  before { stub_connection(current_user: user_entity) }

  it "subscribes to the current user's import stream" do
    subscribe

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from(TransactionImportChannel.broadcasting_for(user.id))
  end
end
