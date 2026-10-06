class Core::Transaction::Import::Rule::Creation < ApplicationSolidProcess
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
    attribute :name, :string
    attribute :position, :integer, default: 0
    attribute :active, :boolean, default: true
    attribute :match_type, :string, default: Core::Transaction::Import::Rule::MatchType::CONTAINS
    attribute :pattern, :string
    attribute :case_sensitive, :boolean, default: false
    attribute :target_column, :string, default: Core::Transaction::Import::Rule::TargetColumn::BOTH
    attribute :effects, default: -> { [] }

    normalizes :name, with: ->(value) { value&.strip }
    normalizes :match_type, :target_column, with: ->(value) { value&.strip.presence }
    normalizes :effects, with: ->(value) { Core::Transaction::Import::Rule::Effect::Attributes.normalize(value) || [] }

    validates :user, :name, :pattern, :match_type, :target_column, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :match_type, inclusion: { in: Core::Transaction::Import::Rule::MatchType::ALL }
    validates :target_column, inclusion: { in: Core::Transaction::Import::Rule::TargetColumn::ALL }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:validate_pattern)
      .and_then(:validate_effects)
      .and_then(:check_if_name_is_taken)
      .and_then(:create_import_rule)
  end

  private

  def validate_pattern(match_type:, pattern:, **)
    Core::Transaction::Import::Rule::Pattern.validate(input.errors, match_type:, pattern:)

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

  def check_if_name_is_taken(user:, name:, **)
    input.errors.add(:name, :taken) if deps.import_rule_repository.exists?(user:, name:)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def create_import_rule(user:, name:, position:, active:, match_type:, pattern:, case_sensitive:, target_column:, effects:, **)
    attributes = { name:, position:, active:, match_type:, pattern:, case_sensitive:, target_column:, effects: }

    case deps.import_rule_repository.create(user:, attributes:)
    in Solid::Success(import_rule:) then Continue(import_rule:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :import_rule_creation_failed)

      Failure(:import_rule_creation_failed, input:)
    end
  end
end
