class Core::Tag::Listing < ApplicationSolidProcess
  DEFAULT_SORTING = "active desc, name asc"

  deps do
    attribute :tag_repository, default: -> { Tag::Adapters.repository }

    validates :tag_repository, kind_of: Core::Tag::Repository::Interface
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
      .and_then(:list_tags)
  end

  private

  def list_tags(user:, filters:, sorting:, page:, per_page:, **)
    case deps.tag_repository.list(user:, filters:, sorting:, page:, per_page:)
    in Solid::Success(tags:, pagination:)
      Continue(tags:, pagination:)
    in Solid::Failure(type: :invalid_filters)
      input.errors.add(:q, :invalid)

      Failure(:invalid_filters, input:)
    end
  end
end
