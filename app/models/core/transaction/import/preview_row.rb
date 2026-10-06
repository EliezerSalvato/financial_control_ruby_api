class Core::Transaction::Import::PreviewRow < ApplicationSolidProcess
  DATA_COLUMNS = %i[date description source_column amount category tags recurrence_type ends_on].freeze

  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :import_rule_repository, default: -> { Transaction::Adapters.import_rule_repository }
    attribute :category_repository, default: -> { Category::Adapters.repository }
    attribute :tag_repository, default: -> { Tag::Adapters.repository }
    attribute :transaction_repository, default: -> { Transaction::Adapters.repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :import_rule_repository, kind_of: Core::Transaction::Import::Rule::Repository::Interface
    validates :category_repository, kind_of: Core::Category::Repository::Interface
    validates :tag_repository, kind_of: Core::Tag::Repository::Interface
    validates :transaction_repository, kind_of: Core::Transaction::Repository::Interface
  end

  input do
    attribute :user_id, :string
    attribute :row, :integer
    attribute :data, default: -> { {} }
    attribute :occurrence, :integer, default: 1
    attribute :defaults, default: -> { {} }

    validates :user_id, :row, presence: true
    validates :data, :defaults, kind_of: Hash
    validates :occurrence, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_user)
      .and_then(:normalize_row)
      .and_then(:apply_rules)
      .and_then(:resolve_category)
      .and_then(:resolve_tags)
      .and_then(:build_source_key)
      .and_then(:ensure_not_imported)
      .and_then(:build_preview)
  end

  private

  def find_user(user_id:, **)
    case deps.user_repository.find_by_id(id: user_id)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure(type: :user_not_found) then Failure(:user_not_found)
    end
  end

  def normalize_row(data:, **)
    case Core::Transaction::Import::RowNormalizing.call(**data.to_h.symbolize_keys.slice(*DATA_COLUMNS))
    in Solid::Success(row: normalized) then Continue(normalized:)
    in Solid::Failure(input: row_input) then Failure(:invalid_row, input: row_input)
    end
  end

  def apply_rules(user:, normalized:, **)
    case deps.import_rule_repository.list_active(user:)
    in Solid::Success(import_rules:)
      applied = Core::Transaction::Import::Rule::Applying.call(row: normalized, rules: import_rules)
      return Failure(:skipped_by_rule) if applied[:skipped]

      applied[:recurrence_type] ||= Core::Transaction::RecurrenceType::ONE_TIME

      Continue(normalized: applied)
    end
  end

  def resolve_category(user:, normalized:, **)
    return resolve_category_by_id(user:, id: normalized[:category_id]) if normalized[:category_id].present?

    name = normalized[:category_name]
    return Continue(category: nil) if name.blank?

    case deps.category_repository.find_by_name(user:, name:)
    in Solid::Success(category:) then Continue(category: { id: category.id, name: category.name, new: false })
    in Solid::Failure(type: :category_not_found) then Continue(category: { name:, new: true })
    end
  end

  # A rule effect may point to a category deleted after the rule was saved.
  def resolve_category_by_id(user:, id:)
    case deps.category_repository.find_by_id(user:, id:)
    in Solid::Success(category:) then Continue(category: { id: category.id, name: category.name, new: false })
    in Solid::Failure(type: :category_not_found) then Continue(category: nil)
    end
  end

  def resolve_tags(user:, normalized:, **)
    names = normalized[:tag_names]

    case deps.tag_repository.find_all_by_names(user:, names:)
    in Solid::Success(tags:)
      existing = tags.index_by { |tag| tag.name.downcase }
      from_names = names.map do |name|
        tag = existing[name.downcase]
        tag ? { id: tag.id, name: tag.name, new: false } : { name:, new: true }
      end

      Continue(tags: from_names + tags_from_rules(user:, ids: normalized[:tag_ids], known: from_names))
    end
  end

  # Tags deleted after the rule was saved are simply not found.
  def tags_from_rules(user:, ids:, known:)
    case deps.tag_repository.find_all_by_ids(user:, ids:)
    in Solid::Success(tags:)
      known_ids = known.filter_map { |tag| tag[:id] }

      tags.reject { |tag| known_ids.include?(tag.id) }.map { |tag| { id: tag.id, name: tag.name, new: false } }
    end
  end

  def build_source_key(normalized:, occurrence:, **)
    source_key = Core::Transaction::Import::SourceKey.build(
      date: normalized[:date], description: normalized[:description], amount: normalized[:amount], occurrence:
    )

    Continue(source_key:)
  end

  def ensure_not_imported(user:, source_key:, **)
    return Continue() unless deps.transaction_repository.exists_by_source_key?(user:, source_key:)

    Failure(:already_imported)
  end

  # limit_consumption_type and installments_count only apply to installment rows.
  def installment_defaults(defaults:, recurrence_type:, installments_count:)
    return { limit_consumption_type: nil, installments_count: nil } unless recurrence_type == Core::Transaction::RecurrenceType::INSTALLMENT

    defaults.to_h.symbolize_keys.slice(:limit_consumption_type, :installments_count).merge(installments_count: installments_count || defaults.to_h.symbolize_keys[:installments_count])
  end

  def build_preview(normalized:, defaults:, category:, tags:, source_key:, **)
    Continue(
      row: {
        date: normalized[:date].iso8601,
        description: normalized[:description],
        original_description: normalized[:original_description],
        amount: format("%.2f", normalized[:amount]),
        recurrence_type: normalized[:recurrence_type],
        ends_on: normalized[:ends_on]&.iso8601,
        **defaults.to_h.symbolize_keys,
        **installment_defaults(defaults:, recurrence_type: normalized[:recurrence_type], installments_count: normalized[:installments_count]),
        category:,
        tags:,
        source_key:,
        applied_rules: normalized[:applied_rules]
      }
    )
  end
end
