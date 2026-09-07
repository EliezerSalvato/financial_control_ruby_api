module MonthlyStatus::Repository::Adapters::ActiveRecord
  include Core::MonthlyStatus::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def find(user_id:, month:, year:)
    record = MonthlyStatus::Record.find_by(user_id:, month:, year:)

    return Success(:monthly_status_found, monthly_status: MonthlyStatus::Mapper.to_entity(record)) if record.present?

    Failure(:monthly_status_not_found)
  end

  def create(user_id:, month:, year:)
    record = MonthlyStatus::Record.create(user_id:, month:, year:, status: Core::MonthlyStatus::Status::OPEN)

    return Success(:monthly_status_created, monthly_status: MonthlyStatus::Mapper.to_entity(record)) if record.persisted?

    Failure(:monthly_status_creation_failed, errors: MonthlyStatus::Mapper.to_errors(record))
  end

  def update(monthly_status:, attributes:)
    record = MonthlyStatus::Mapper.to_record(monthly_status)
    updated = record.update(attributes)

    return Success(:monthly_status_updated, monthly_status: MonthlyStatus::Mapper.to_entity(record)) if updated

    Failure(:monthly_status_update_failed, errors: MonthlyStatus::Mapper.to_errors(record))
  end

  def close(monthly_status:)
    record = MonthlyStatus::Mapper.to_record(monthly_status)
    updated = record.update(status: Core::MonthlyStatus::Status::CLOSED)

    return Success(:monthly_status_closed, monthly_status: MonthlyStatus::Mapper.to_entity(record)) if updated

    Failure(:monthly_status_closing_failed, errors: MonthlyStatus::Mapper.to_errors(record))
  end

  def list_open(up_to_month:, up_to_year:)
    records = open_up_to(up_to_month:, up_to_year:).order(:user_id, :year, :month)

    Success(:monthly_statuses_listed, monthly_statuses: MonthlyStatus::Mapper.to_entities(records))
  end

  def list_open_for(user_id:, up_to_month:, up_to_year:)
    records = open_up_to(up_to_month:, up_to_year:).where(user_id:).order(:year, :month)

    Success(:monthly_statuses_listed, monthly_statuses: MonthlyStatus::Mapper.to_entities(records))
  end

  def user_ids_with_open_months(up_to_month:, up_to_year:)
    user_ids = open_up_to(up_to_month:, up_to_year:).distinct.pluck(:user_id)

    Success(:user_ids_listed, user_ids:)
  end

  def exists_closed_after?(user_id:, month:, year:)
    MonthlyStatus::Record
      .where(user_id:, status: Core::MonthlyStatus::Status::CLOSED)
      .where("(year, month) > (?, ?)", year, month)
      .exists?
  end

  private

  def open_up_to(up_to_month:, up_to_year:)
    MonthlyStatus::Record
      .where(status: Core::MonthlyStatus::Status::OPEN)
      .where("(year, month) <= (?, ?)", up_to_year, up_to_month)
  end
end
