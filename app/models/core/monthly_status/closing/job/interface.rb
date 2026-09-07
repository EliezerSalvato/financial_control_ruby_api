module Core::MonthlyStatus::Closing::Job::Interface
  include Solid::Adapters::Interface

  module Methods
    def start(user_id:, date:)
      user_id => String
      date => Date

      super
    end

    def schedule(user_id:, date:, wait_until:)
      user_id => String
      date => Date
      wait_until => ActiveSupport::TimeWithZone | Time

      super
    end
  end
end
