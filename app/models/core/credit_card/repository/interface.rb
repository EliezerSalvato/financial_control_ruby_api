module Core::CreditCard::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def list(user:, filters:, sorting:, page:, per_page:)
      user => Core::User::Entity
      filters => Hash
      sorting => String
      page => Integer
      per_page => Integer

      super.tap do
        _1 => (
          Solid::Failure(:invalid_filters, {}) |
          Solid::Success(:credit_cards_listed, { credit_cards: Array, pagination: Core::Pagination::Entity })
        )
      end
    end

    def find_by_id(user:, id:)
      user => Core::User::Entity
      id => String

      super.tap do
        _1 => (
          Solid::Failure(:credit_card_not_found, {}) |
          Solid::Success(:credit_card_found, { credit_card: Core::CreditCard::Entity })
        )
      end
    end

    def exists?(user:, name:, excluding_id: nil)
      user => Core::User::Entity
      name => String
      excluding_id => String | NilClass

      super.tap do
        _1 => (true | false)
      end
    end

    def create(user:, attributes:)
      user => Core::User::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:credit_card_creation_failed, { credit_card: Core::CreditCard::Entity, errors: Core::Errors }) |
          Solid::Success(:credit_card_created, { credit_card: Core::CreditCard::Entity })
        )
      end
    end

    def update(credit_card:, attributes:)
      credit_card => Core::CreditCard::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:credit_card_update_failed, { credit_card: Core::CreditCard::Entity, errors: Core::Errors }) |
          Solid::Success(:credit_card_updated, { credit_card: Core::CreditCard::Entity })
        )
      end
    end

    def destroy(credit_card:)
      credit_card => Core::CreditCard::Entity

      super.tap do
        _1 => (
          Solid::Failure(:credit_card_destruction_failed, {}) |
          Solid::Success(:credit_card_destroyed, {})
        )
      end
    end

    def adjust_available_limit(credit_card:, amount:, operation:)
      credit_card => Core::CreditCard::Entity
      amount => Numeric
      operation => Core::CreditCard::AvailableLimitOperation::ADD | Core::CreditCard::AvailableLimitOperation::SUBTRACT

      super.tap do
        _1 => (
          Solid::Success(:credit_card_available_limit_adjusted, { credit_card: Core::CreditCard::Entity }) |
          Solid::Failure(:insufficient_available_limit, { credit_card: Core::CreditCard::Entity, errors: Core::Errors }) |
          Solid::Failure(:available_limit_exceeds_total_limit, { credit_card: Core::CreditCard::Entity, errors: Core::Errors }) |
          Solid::Failure(:credit_card_available_limit_adjustment_failed, { credit_card: Core::CreditCard::Entity, errors: Core::Errors })
        )
      end
    end

    def billing_cycle_month(user:, credit_card_id:, date:)
      user => Core::User::Entity
      credit_card_id => String
      date => Date

      super.tap do
        _1 => (
          Solid::Failure(:credit_card_not_found, {}) |
          Solid::Success(:credit_card_billing_cycle_month_resolved, { month: Integer, year: Integer })
        )
      end
    end
  end
end
