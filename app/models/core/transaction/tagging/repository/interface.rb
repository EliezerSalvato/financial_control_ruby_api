module Core::Transaction::Tagging::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def sync(transaction:, tag_ids:)
      transaction => Core::Transaction::Entity
      tag_ids => Array
      tag_ids.all? { |id| UUID.valid?(id) } => true

      super.tap do
        _1 => (
          Solid::Failure(:taggings_replace_failed, { errors: Core::Errors }) |
          Solid::Success(:taggings_replaced, {})
        )
      end
    end
  end
end
