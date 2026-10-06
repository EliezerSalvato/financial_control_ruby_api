class Core::Transaction::Import::Rule::Listing < ApplicationSolidProcess
  DEFAULT_SORTING = "position asc, name asc"

  deps do
    attribute :import_rule_repository, default: -> { Transaction::Adapters.import_rule_repository }

    validates :import_rule_repository, kind_of: Core::Transaction::Import::Rule::Repository::Interface
  end

  input do
    attribute :user
    attribute :filters, default: -> { {} }
    attribute :sorting, :string, default: DEFAULT_SORTING
    attribute :page, :integer, default: 1
    attribute :per_page, :integer, default: Core::Pagination::DEFAULT_PER_PAGE

    validates :user, presence: true, kind_of: Core::User::Entity
    validates :filters, kind_of: Hash
    validates :sorting, presence: true
    validates :page, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :per_page, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: Core::Pagination::MAX_PER_PAGE
    }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:list_import_rules)
  end

  private

  def list_import_rules(user:, filters:, sorting:, page:, per_page:, **)
    case deps.import_rule_repository.list(user:, filters:, sorting:, page:, per_page:)
    in Solid::Success(import_rules:, pagination:)
      Continue(import_rules:, pagination:)
    in Solid::Failure(type: :invalid_filters)
      input.errors.add(:q, :invalid)

      Failure(:invalid_filters, input:)
    end
  end
end
