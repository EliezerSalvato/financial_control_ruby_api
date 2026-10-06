module Core::Transaction::Import::PreviewRow::Job::Interface
  include Solid::Adapters::Interface

  module Methods
    def start(user_id:, import_id:, row:, data:, occurrence:, defaults:)
      UUID.valid?(user_id) => true
      UUID.valid?(import_id) => true
      row => Integer
      data => Hash
      occurrence => Integer
      defaults => Hash

      super
    end
  end
end
