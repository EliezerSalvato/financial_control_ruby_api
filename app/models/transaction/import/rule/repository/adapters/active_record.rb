module Transaction::Import::Rule::Repository::Adapters::ActiveRecord
  include Core::Transaction::Import::Rule::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list(user:, filters:, sorting:, page:, per_page:)
    sorts = sorting.to_s.split(",").map(&:strip)
    query = user_import_rules(user).ransack(filters.merge(s: sorts))
    records, pagination = Pagination.paginate(query.result, page:, per_page:)

    Success(:import_rules_listed, import_rules: Transaction::Import::Rule::Mapper.to_entities(records), pagination:)
  rescue Ransack::InvalidSearchError, ArgumentError, Pagy::OptionError
    Failure(:invalid_filters)
  end

  def list_active(user:)
    records = user_import_rules(user).where(active: true).order(:position, :created_at).to_a

    Success(:import_rules_found, import_rules: Transaction::Import::Rule::Mapper.to_entities(records))
  end

  def find_by_id(user:, id:)
    record = user_import_rules(user).find_by(id:)

    return Success(:import_rule_found, import_rule: Transaction::Import::Rule::Mapper.to_entity(record)) if record.present?

    Failure(:import_rule_not_found)
  end

  def exists?(user:, name:, excluding_id: nil)
    scope = user_import_rules(user).where("LOWER(name) = LOWER(?)", name)
    scope = scope.where.not(id: excluding_id) if excluding_id.present?

    scope.exists?
  end

  def create(user:, attributes:)
    record = Transaction::Import::Rule::Record.new(attributes.except(:effects).merge(user_id: user.id))
    record.effects.build(attributes.fetch(:effects, []))
    save_and_place(record, attributes[:position])

    return Success(:import_rule_created, import_rule: Transaction::Import::Rule::Mapper.to_entity(record)) if record.persisted?

    Failure(
      :import_rule_creation_failed,
      import_rule: Transaction::Import::Rule::Mapper.to_entity(record),
      errors: Transaction::Import::Rule::Mapper.to_errors(record)
    )
  end

  def update(import_rule:, attributes:)
    record = Transaction::Import::Rule::Mapper.to_record(import_rule)

    return Success(:import_rule_updated, import_rule: Transaction::Import::Rule::Mapper.to_entity(record)) if update_record(record, attributes)

    Failure(
      :import_rule_update_failed,
      import_rule: Transaction::Import::Rule::Mapper.to_entity(record),
      errors: Transaction::Import::Rule::Mapper.to_errors(record)
    )
  end

  def destroy(import_rule:)
    record = Transaction::Import::Rule::Mapper.to_record(import_rule)

    return Success(:import_rule_destroyed) if destroy_and_compact(record)

    Failure(:import_rule_destruction_failed)
  end

  private

  def update_record(record, attributes)
    effects = attributes[:effects]

    Transaction::Import::Rule::Record.transaction do
      record.effects = effects.map { |effect| Transaction::Import::Rule::Effect::Record.new(effect) } unless effects.nil?

      record.update(attributes.except(:effects)) || raise(ActiveRecord::Rollback)
      place(record, attributes[:position]) if attributes.key?(:position)
      true
    end
  end

  def save_and_place(record, position)
    Transaction::Import::Rule::Record.transaction do
      record.save || raise(ActiveRecord::Rollback)
      place(record, position)
    end
  end

  def destroy_and_compact(record)
    Transaction::Import::Rule::Record.transaction do
      record.destroy || raise(ActiveRecord::Rollback)
      resequence(sibling_ids(record))
      true
    end
  end

  def place(record, position)
    ids = sibling_ids(record)
    index = position.to_i.clamp(0, ids.size)
    ids.insert(index, record.id)

    resequence(ids)
    record.position = index
    record.clear_attribute_changes(%w[position])
  end

  def sibling_ids(record)
    Transaction::Import::Rule::Record
      .where(user_id: record.user_id).where.not(id: record.id)
      .order(:position, :created_at).pluck(:id)
  end

  def resequence(ids)
    ids.each_with_index do |id, index|
      Transaction::Import::Rule::Record.where(id:).where.not(position: index).update_all(position: index)
    end
  end

  def user_import_rules(user)
    Transaction::Import::Rule::Record.includes(:effects).where(user_id: user.id)
  end
end
