module Category::Goal::Repository::Adapters::ActiveRecord
  include Core::Category::Goal::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def create(category:, starts_on:, value:)
    record = Category::Goal::Record.create(
      category_id: category.id,
      month: starts_on.month,
      year: starts_on.year,
      value:
    )

    return Success(:goal_created, goal: Category::Goal::Mapper.to_entity(record)) if record.persisted?

    Failure(:goal_creation_failed, errors: Category::Goal::Mapper.to_errors(record))
  end

  def find_by_starts_on(category:, starts_on:)
    record = Category::Goal::Record.find_by(category_id: category.id, month: starts_on.month, year: starts_on.year)

    return Success(:goal_found, goal: Category::Goal::Mapper.to_entity(record)) if record.present?

    Failure(:goal_not_found)
  end

  def find_latest(category:)
    record = Category::Goal::Record.where(category_id: category.id).order(year: :desc, month: :desc).first

    return Success(:goal_found, goal: Category::Goal::Mapper.to_entity(record)) if record.present?

    Failure(:goal_not_found)
  end

  def update(goal:, attributes:)
    record = Category::Goal::Mapper.to_record(goal)
    updated = record.update(attributes.compact)

    return Success(:goal_updated, goal: Category::Goal::Mapper.to_entity(record)) if updated

    Failure(:goal_update_failed, errors: Category::Goal::Mapper.to_errors(record))
  end

  def destroy_after(category:, starts_on:)
    records = later_than(category_id: category.id, starts_on:)

    records.each do |record|
      next if closed_month?(user_id: category.user_id, month: record.month, year: record.year)
      next if record.destroy

      return Failure(:goal_destruction_failed, errors: Category::Goal::Mapper.to_errors(record))
    end

    Success(:goals_destroyed)
  end

  private

  def later_than(category_id:, starts_on:)
    next_month = Date.new(starts_on.year, starts_on.month, 1).next_month

    Category::Goal::Record.where(category_id:).where(
      "year > :year OR (year = :year AND month >= :month)",
      year: next_month.year,
      month: next_month.month
    )
  end

  def closed_month?(user_id:, month:, year:)
    MonthlyStatus::Record.exists?(user_id:, month:, year:, status: Core::MonthlyStatus::Status::CLOSED)
  end
end
