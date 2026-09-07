require "rails_helper"

class ApplicationJobRetryTestJob < ApplicationJob
  class << self
    attr_accessor :executions_count
  end

  def perform
    self.class.executions_count += 1
    raise StandardError, "always fails"
  end
end

RSpec.describe ApplicationJob, type: :job do
  include ActiveJob::TestHelper

  before { ApplicationJobRetryTestJob.executions_count = 0 }

  it "retries a generic error 5 times and then raises back to the queue" do
    expect {
      perform_enqueued_jobs(at: 1.day.from_now) { ApplicationJobRetryTestJob.perform_later }
    }.to raise_error(Minitest::UnexpectedError) { |error|
      expect(error.cause).to be_a(StandardError)
      expect(error.cause.message).to eq("always fails")
    }

    expect(ApplicationJobRetryTestJob.executions_count).to eq(5)
  end
end
