module MonthlyStatus::Repository::Adapters::ActiveRecord
  include Core::MonthlyStatus::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def find(user_id:, month:, year:)
    record = MonthlyStatus::Record.find_by(user_id:, month:, year:)

    return Success(:monthly_status_found, monthly_status: MonthlyStatus::Mapper.to_entity(record)) if record.present?

    Failure(:monthly_status_not_found)
  end

  def find_or_create(user_id:, month:, year:)
    record = MonthlyStatus::Record.create_or_find_by(user_id:, month:, year:) do |monthly_status|
      monthly_status.status = Core::MonthlyStatus::Status::OPEN
    end

    return Success(:monthly_status_found, monthly_status: MonthlyStatus::Mapper.to_entity(record)) if record.persisted?

    Failure(:monthly_status_creation_failed, errors: MonthlyStatus::Mapper.to_errors(record))
  end

  def update(monthly_status:, attributes:)
    record = MonthlyStatus::Mapper.to_record(monthly_status)
    updated = record.update(status: attributes.fetch(:status))

    return Success(:monthly_status_updated, monthly_status: MonthlyStatus::Mapper.to_entity(record)) if updated

    Failure(:monthly_status_update_failed, errors: MonthlyStatus::Mapper.to_errors(record))
  end
end
