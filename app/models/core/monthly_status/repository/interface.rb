module Core::MonthlyStatus::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def find(user_id:, month:, year:)
      UUID.valid?(user_id) => true
      month => Integer
      year => Integer

      super.tap do
        _1 => (
          Solid::Failure(:monthly_status_not_found, {}) |
          Solid::Success(:monthly_status_found, { monthly_status: Core::MonthlyStatus::Entity })
        )
      end
    end

    def create(user_id:, month:, year:)
      UUID.valid?(user_id) => true
      month => Integer
      year => Integer

      super.tap do
        _1 => (
          Solid::Failure(:monthly_status_creation_failed, { errors: Core::Errors }) |
          Solid::Success(:monthly_status_created, { monthly_status: Core::MonthlyStatus::Entity })
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

    def close(monthly_status:)
      monthly_status => Core::MonthlyStatus::Entity

      super.tap do
        _1 => (
          Solid::Failure(:monthly_status_closing_failed, { errors: Core::Errors }) |
          Solid::Success(:monthly_status_closed, { monthly_status: Core::MonthlyStatus::Entity })
        )
      end
    end

    def list_open(up_to_month:, up_to_year:)
      up_to_month => Integer
      up_to_year => Integer

      super.tap do
        _1 => Solid::Success(:monthly_statuses_listed, { monthly_statuses: Array })
      end
    end

    def list_open_for(user_id:, up_to_month:, up_to_year:)
      UUID.valid?(user_id) => true
      up_to_month => Integer
      up_to_year => Integer

      super.tap do
        _1 => Solid::Success(:monthly_statuses_listed, { monthly_statuses: Array })
      end
    end

    def user_ids_with_open_months(up_to_month:, up_to_year:)
      up_to_month => Integer
      up_to_year => Integer

      super.tap do
        _1 => Solid::Success(:user_ids_listed, { user_ids: Array })
      end
    end

    def exists_closed_after?(user_id:, month:, year:)
      UUID.valid?(user_id) => true
      month => Integer
      year => Integer

      super.tap do
        _1 => (true | false)
      end
    end
  end
end
