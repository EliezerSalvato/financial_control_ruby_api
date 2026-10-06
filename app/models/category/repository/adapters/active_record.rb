module Category::Repository::Adapters::ActiveRecord
  include Core::Category::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list(user:, filters:, sorting:, page:, per_page:)
    scope = user_categories(user)
    sorts = sorting.to_s.split(",").map(&:strip)
    query = scope.ransack(filters.merge(s: sorts))
    records, pagination = Pagination.paginate(query.result, page:, per_page:)

    Success(:categories_listed, categories: Category::Mapper.to_entities(records), pagination:)
  rescue Ransack::InvalidSearchError, ArgumentError, Pagy::OptionError
    Failure(:invalid_filters)
  end

  def find_by_id(user:, id:)
    category = user_categories(user).find_by(id:)

    return Success(:category_found, category: Category::Mapper.to_entity(category)) if category.present?

    Failure(:category_not_found)
  end

  def find_by_name(user:, name:)
    category = find_record_by_name(user:, name:)

    return Success(:category_found, category: Category::Mapper.to_entity(category)) if category.present?

    Failure(:category_not_found)
  end

  def find_or_create_by_name(user:, name:, color:)
    category = find_record_by_name(user:, name:)
    category ||= create_record_by_name(user:, name:, color:)

    return Success(:category_found, category: Category::Mapper.to_entity(category)) if category.persisted?

    Failure(:category_creation_failed, errors: Category::Mapper.to_errors(category))
  end

  def exists?(user:, name:, excluding_id: nil)
    scope = user_categories(user).where("LOWER(name) = LOWER(?)", name)
    scope = scope.where.not(id: excluding_id) if excluding_id.present?

    scope.exists?
  end

  def create(user:, attributes:)
    category = user_categories(user).create(attributes)

    return Success(:category_created, category: Category::Mapper.to_entity(category)) if category.persisted?

    Failure(:category_creation_failed, category: Category::Mapper.to_entity(category), errors: Category::Mapper.to_errors(category))
  end

  def update(category:, attributes:)
    record = Category::Mapper.to_record(category)
    updated = record.update(attributes)

    return Success(:category_updated, category: Category::Mapper.to_entity(record)) if updated

    Failure(:category_update_failed, category: Category::Mapper.to_entity(record), errors: Category::Mapper.to_errors(record))
  end

  def destroy(category:)
    record = Category::Mapper.to_record(category)

    return Success(:category_destroyed) if record.destroy

    Failure(:category_destruction_failed)
  end

  private

  def find_record_by_name(user:, name:)
    user_categories(user).find_by("LOWER(categories.name) = LOWER(?)", name)
  end

  def create_record_by_name(user:, name:, color:)
    Category::Record.transaction(requires_new: true) { user_categories(user).create(name:, color:) }
  rescue ActiveRecord::RecordNotUnique
    find_record_by_name(user:, name:)
  end

  def user_categories(user)
    Category::Record.where(user_id: user.id).includes(:goals)
  end
end
