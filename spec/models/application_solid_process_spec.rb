require "rails_helper"

class ApplicationSolidProcessCoverageProcess < ApplicationSolidProcess
  input do
    attribute :name, :string
    attribute :nested_result
  end

  def call(attributes)
    Given(attributes)
      .and_then(:handle_nested)
  end

  private

  def handle_nested(nested_result: nil, **)
    return Continue() if nested_result.nil?

    with_nested_process(nested_result, persist_failure: :persist_failed)
  end
end

RSpec.describe ApplicationSolidProcess do
  def nested_input_with_error
    ApplicationSolidProcessCoverageProcess::Input.new.tap { |input| input.errors.add(:name, :invalid) }
  end

  it "merges nested invalid_input errors onto the parent input" do
    result = ApplicationSolidProcessCoverageProcess.call(
      name: "ok",
      nested_result: Solid::Failure(:invalid_input, input: nested_input_with_error)
    )

    expect(result).to be_a(Solid::Failure)
    expect(result.type).to eq(:invalid_input)
    expect(result.value[:input].errors.details[:name]).to be_present
  end

  it "merges nested failures that expose input without an errors key" do
    result = ApplicationSolidProcessCoverageProcess.call(
      name: "ok",
      nested_result: Solid::Failure(:account_creation_failed, input: nested_input_with_error)
    )

    expect(result).to be_a(Solid::Failure)
    expect(result.type).to eq(:invalid_input)
    expect(result.value[:input].errors.details[:name]).to be_present
  end

  it "adds persist_failure onto the parent when the nested result exposes errors" do
    result = ApplicationSolidProcessCoverageProcess.call(
      name: "ok",
      nested_result: Solid::Failure(:for_account_creation_failed, errors: Core::Errors.new(base: [ "nope" ]))
    )

    expect(result).to be_a(Solid::Failure)
    expect(result.type).to eq(:persist_failed)
    expect(result.value[:input].errors.details[:base]).to be_present
  end

  describe "#to_core_errors" do
    let(:process) { ApplicationSolidProcessCoverageProcess.new }

    it "wraps an object that responds to errors" do
      source = Struct.new(:errors).new(Struct.new(:messages).new({ name: [ "taken" ] }))

      expect(process.send(:to_core_errors, source).messages).to eq(name: [ "taken" ])
    end

    it "wraps an object that responds to messages" do
      source = Struct.new(:messages).new({ name: [ "invalid" ] })

      expect(process.send(:to_core_errors, source).messages).to eq(name: [ "invalid" ])
    end

    it "raises when the source is unsupported" do
      expect { process.send(:to_core_errors, :nope) }.to raise_error(ArgumentError, /unsupported errors source/)
    end
  end
end
