class Core::Transaction::Import::Rule::Update < ApplicationSolidProcess
  deps do
    attribute :import_rule_repository, default: -> { Transaction::Adapters.import_rule_repository }

    attribute :category_repository, default: -> { Category::Adapters.repository }
    attribute :tag_repository, default: -> { Tag::Adapters.repository }

    validates :import_rule_repository, kind_of: Core::Transaction::Import::Rule::Repository::Interface
    validates :category_repository, kind_of: Core::Category::Repository::Interface
    validates :tag_repository, kind_of: Core::Tag::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string
    attribute :name, :string
    attribute :position, :integer
    attribute :active, :boolean
    attribute :match_type, :string
    attribute :pattern, :string
    attribute :case_sensitive, :boolean
    attribute :target_column, :string
    attribute :effects

    normalizes :name, :match_type, :target_column, with: ->(value) { value&.strip }
    normalizes :effects, with: ->(value) { Core::Transaction::Import::Rule::Effect::Attributes.normalize(value) }

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :name, :pattern, presence: true, allow_nil: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :match_type, inclusion: { in: Core::Transaction::Import::Rule::MatchType::ALL }, allow_nil: true
    validates :target_column, inclusion: { in: Core::Transaction::Import::Rule::TargetColumn::ALL }, allow_nil: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_import_rule)
      .and_then(:validate_pattern)
      .and_then(:validate_effects)
      .and_then(:check_if_name_is_taken)
      .and_then(:update_import_rule)
  end

  private

  def find_import_rule(user:, id:, **)
    case deps.import_rule_repository.find_by_id(user:, id:)
    in Solid::Success(import_rule:) then Continue(import_rule:)
    in Solid::Failure(type: :import_rule_not_found) then Failure(:import_rule_not_found)
    end
  end

  def validate_pattern(import_rule:, match_type:, pattern:, **)
    Core::Transaction::Import::Rule::Pattern.validate(
      input.errors,
      match_type: match_type || import_rule.match_type,
      pattern: pattern || import_rule.pattern
    )

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def validate_effects(user:, effects:, **)
    Core::Transaction::Import::Rule::Effect::Attributes.validate(input.errors, effects)
    return Failure(:invalid_input, input:) if input.errors.any?

    Core::Transaction::Import::Rule::Effect::References.validate(
      input.errors,
      user:, effects:, category_repository: deps.category_repository, tag_repository: deps.tag_repository
    )

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def check_if_name_is_taken(user:, name:, import_rule:, **)
    return Continue() if name.nil?

    input.errors.add(:name, :taken) if deps.import_rule_repository.exists?(user:, name:, excluding_id: import_rule.id)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  # `effects` replaces the whole list when present; nil leaves the current effects untouched.
  def update_import_rule(import_rule:, name:, position:, active:, match_type:, pattern:, case_sensitive:, target_column:, effects:, **)
    attributes = { name:, position:, active:, match_type:, pattern:, case_sensitive:, target_column:, effects: }.compact

    case deps.import_rule_repository.update(import_rule:, attributes:)
    in Solid::Success(import_rule:) then Continue(import_rule:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :import_rule_update_failed)

      Failure(:import_rule_update_failed, input:)
    end
  end
end
