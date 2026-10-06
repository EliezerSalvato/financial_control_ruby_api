module Core::Transaction::Import::PersistRow::Job::Interface
  include Solid::Adapters::Interface

  module Methods
    def start(user_id:, import_id:, row:)
      UUID.valid?(user_id) => true
      UUID.valid?(import_id) => true
      row => Hash

      super
    end
  end
end
