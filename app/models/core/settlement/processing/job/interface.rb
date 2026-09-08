module Core::Settlement::Processing::Job::Interface
  include Solid::Adapters::Interface

  module Methods
    def start(user_id:, month:, year:, reference_date:)
      UUID.valid?(user_id) => true
      month => Integer
      year => Integer
      reference_date => Date

      super
    end
  end
end
