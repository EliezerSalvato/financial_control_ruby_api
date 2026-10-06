module Tag::Repository::Adapters::ActiveRecord
  include Core::Tag::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list(user:, filters:, sorting:, page:, per_page:)
    scope = user_tags(user)
    sorts = sorting.to_s.split(",").map(&:strip)
    query = scope.ransack(filters.merge(s: sorts))
    records, pagination = Pagination.paginate(query.result, page:, per_page:)

    Success(:tags_listed, tags: Tag::Mapper.to_entities(records), pagination:)
  rescue Ransack::InvalidSearchError, ArgumentError, Pagy::OptionError
    Failure(:invalid_filters)
  end

  def find_by_id(user:, id:)
    tag = user_tags(user).find_by(id:)

    return Success(:tag_found, tag: Tag::Mapper.to_entity(tag)) if tag.present?

    Failure(:tag_not_found)
  end

  def find_by_ids(user:, ids:)
    records = user_tags(user).where(id: ids).to_a

    return Failure(:tags_not_found) unless records.size == ids.uniq.size

    Success(:tags_found, tags: Tag::Mapper.to_entities(records))
  end

  def find_all_by_ids(user:, ids:)
    Success(:tags_found, tags: Tag::Mapper.to_entities(user_tags(user).where(id: ids).to_a))
  end

  def find_all_by_names(user:, names:)
    Success(:tags_found, tags: Tag::Mapper.to_entities(find_records_by_names(user:, names:)))
  end

  def find_or_create_by_names(user:, names:, color:)
    records = find_records_by_names(user:, names:)
    known = records.map { |record| record.name.downcase }

    names.uniq(&:downcase).sort_by(&:downcase).each do |name|
      next if known.include?(name.downcase)

      record = create_record_by_name(user:, name:, color:)

      return Failure(:tag_creation_failed, errors: Tag::Mapper.to_errors(record)) unless record.persisted?

      records << record
    end

    Success(:tags_found, tags: Tag::Mapper.to_entities(records))
  end

  def exists?(user:, name:, excluding_id: nil)
    scope = user_tags(user).where("LOWER(name) = LOWER(?)", name)
    scope = scope.where.not(id: excluding_id) if excluding_id.present?

    scope.exists?
  end

  def create(user:, attributes:)
    tag = user_tags(user).create(attributes)

    return Success(:tag_created, tag: Tag::Mapper.to_entity(tag)) if tag.persisted?

    Failure(:tag_creation_failed, tag: Tag::Mapper.to_entity(tag), errors: Tag::Mapper.to_errors(tag))
  end

  def update(tag:, attributes:)
    record = Tag::Mapper.to_record(tag)
    updated = record.update(attributes)

    return Success(:tag_updated, tag: Tag::Mapper.to_entity(record)) if updated

    Failure(:tag_update_failed, tag: Tag::Mapper.to_entity(record), errors: Tag::Mapper.to_errors(record))
  end

  def destroy(tag:)
    record = Tag::Mapper.to_record(tag)

    return Success(:tag_destroyed) if record.destroy

    Failure(:tag_destruction_failed)
  end

  private

  def find_records_by_names(user:, names:)
    return [] if names.empty?

    user_tags(user).where("LOWER(tags.name) IN (?)", names.map(&:downcase)).to_a
  end

  def create_record_by_name(user:, name:, color:)
    Tag::Record.transaction(requires_new: true) { user_tags(user).create(name:, color:) }
  rescue ActiveRecord::RecordNotUnique
    find_records_by_names(user:, names: [ name ]).first
  end

  def user_tags(user)
    Tag::Record.where(user_id: user.id).includes(:goals)
  end
end
