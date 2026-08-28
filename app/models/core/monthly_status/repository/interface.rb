module Core::MonthlyStatus::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def find(user_id:, month:, year:)
      user_id => String
      month => Integer
      year => Integer

      super.tap do
        _1 => (
          Solid::Failure(:monthly_status_not_found, {}) |
          Solid::Success(:monthly_status_found, { monthly_status: Core::MonthlyStatus::Entity })
        )
      end
    end

    def find_or_create(user_id:, month:, year:)
      user_id => String
      month => Integer
      year => Integer

      super.tap do
        _1 => (
          Solid::Failure(:monthly_status_creation_failed, { errors: Core::Errors }) |
          Solid::Success(:monthly_status_found, { monthly_status: Core::MonthlyStatus::Entity })
        )
      end
    end

    def update(monthly_status:, attributes:)
      monthly_status => Core::MonthlyStatus::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:monthly_status_update_failed, { errors: Core::Errors }) |
          Solid::Success(:monthly_status_updated, { monthly_status: Core::MonthlyStatus::Entity })
        )
      end
    end
  end
end
