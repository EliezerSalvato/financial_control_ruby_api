module Institution::Repository::Adapters::ActiveRecord
  include Core::Institution::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list(user:, filters:, sorting:, page:, per_page:)
    scope = user_institutions(user)
    sorts = sorting.to_s.split(",").map(&:strip)
    query = scope.ransack(filters.merge(s: sorts))
    records, pagination = Pagination.paginate(query.result, page:, per_page:)

    Success(:institutions_listed, institutions: Institution::Mapper.to_entities(records), pagination:)
  rescue Ransack::InvalidSearchError, ArgumentError, Pagy::OptionError
    Failure(:invalid_filters)
  end

  def find_by_id(user:, id:)
    institution = user_institutions(user).find_by(id:)

    return Success(:institution_found, institution: Institution::Mapper.to_entity(institution)) if institution.present?

    Failure(:institution_not_found)
  end

  def exists?(user:, name:, excluding_id: nil)
    scope = user_institutions(user).where("LOWER(name) = LOWER(?)", name)
    scope = scope.where.not(id: excluding_id) if excluding_id.present?

    scope.exists?
  end

  def create(user:, attributes:)
    institution = user_institutions(user).create(attributes)

    return Success(:institution_created, institution: Institution::Mapper.to_entity(institution)) if institution.persisted?

    Failure(:institution_creation_failed, institution: Institution::Mapper.to_entity(institution), errors: Institution::Mapper.to_errors(institution))
  end

  def update(institution:, attributes:)
    record = Institution::Mapper.to_record(institution)
    updated = record.update(attributes)

    return Success(:institution_updated, institution: Institution::Mapper.to_entity(record)) if updated

    Failure(:institution_update_failed, institution: Institution::Mapper.to_entity(record), errors: Institution::Mapper.to_errors(record))
  end

  def destroy(institution:)
    record = Institution::Mapper.to_record(institution)

    return Success(:institution_destroyed) if record.destroy

    Failure(:institution_destruction_failed)
  end

  private

  def user_institutions(user)
    Institution::Record.where(user_id: user.id)
  end
end
