class Core::Category::Finding < ApplicationSolidProcess
  deps do
    attribute :category_repository, default: -> { Category::Adapters.repository }

    validates :category_repository, kind_of: Core::Category::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_category)
  end

  private

  def find_category(user:, id:, **)
    case deps.category_repository.find_by_id(user:, id:)
    in Solid::Success(category:) then Continue(category:)
    in Solid::Failure(type: :category_not_found) then Failure(:category_not_found)
    end
  end
end
