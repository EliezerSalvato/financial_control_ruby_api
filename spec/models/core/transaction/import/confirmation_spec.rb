require "rails_helper"

RSpec.describe Core::Transaction::Import::Confirmation do
  let(:user) { User::Mapper.to_entity(create(:user, :verified)) }

  it "fails without rows" do
    result = described_class.call(user:, import_id: SecureRandom.uuid_v7, rows: [])

    expect(result).to be_failure(:invalid_input)
    expect(result.value[:input].errors.details[:rows].pluck(:error)).to eq([ :blank ])
  end
end
