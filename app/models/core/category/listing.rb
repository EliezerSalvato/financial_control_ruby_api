class Core::Category::Listing < ApplicationSolidProcess
  DEFAULT_SORTING = "active desc, name asc"

  deps do
    attribute :category_repository, default: -> { Category::Adapters.repository }

    validates :category_repository, kind_of: Core::Category::Repository::Interface
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
      .and_then(:list_categories)
  end

  private

  def list_categories(user:, filters:, sorting:, page:, per_page:, **)
    case deps.category_repository.list(user:, filters:, sorting:, page:, per_page:)
    in Solid::Success(categories:, pagination:)
      Continue(categories:, pagination:)
    in Solid::Failure(type: :invalid_filters)
      input.errors.add(:q, :invalid)

      Failure(:invalid_filters, input:)
    end
  end
end
