require "rails_helper"

class RetryableWithLoggingTestJob < ApplicationJob
  include RetryableWithLogging

  class << self
    attr_accessor :executions_count
  end

  def perform
    self.class.executions_count += 1
    raise StandardError, "always fails"
  end
end

RSpec.describe RetryableWithLogging, type: :job do
  include ActiveJob::TestHelper

  before { RetryableWithLoggingTestJob.executions_count = 0 }

  it "runs 5 times, logs on the last attempt, and finishes without re-raising or re-enqueueing" do
    allow(Rails.logger).to receive(:error)

    expect {
      perform_enqueued_jobs(at: 1.day.from_now) { RetryableWithLoggingTestJob.perform_later }
    }.not_to raise_error

    expect(RetryableWithLoggingTestJob.executions_count).to eq(5)
    expect(Rails.logger).to have_received(:error).at_least(:once)
    expect(enqueued_jobs).to be_empty
  end
end
