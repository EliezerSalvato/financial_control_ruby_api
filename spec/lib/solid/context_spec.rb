require "rails_helper"

RSpec.describe Solid::Context do
  describe Solid::Context::Action do
    it "exposes process input and dependency attribute types" do
      action = User.action(:register)

      expect(action.input).to include(email: :string, password: :string)
      expect(action.dependencies).to include(:mailer, :user_repository, :email_confirmation_repository)
    end

    it "returns an empty hash when the process has no input or dependencies" do
      process = double("process", dependencies: nil, input: nil)
      action = described_class.new(:noop, process)

      expect(action.dependencies).to eq({})
      expect(action.input).to eq({})
    end
  end

  describe "#actions" do
    it "lists the registered action names" do
      expect(User.actions).to include(:register, :authenticate)
    end
  end

  describe "#import" do
    it "imports another context as a nested action" do
      host = Module.new { extend Solid::Context }
      child = Class.new { include Solid::Context }.new

      host.import(account: child)

      expect(host.account).to eq(child)
    end

    it "raises when the imported object is not a Solid::Context" do
      host = Module.new { extend Solid::Context }

      expect { host.import(account: Object.new) }.to raise_error(ArgumentError, /Expected a Solid::Context/)
    end
  end
end
