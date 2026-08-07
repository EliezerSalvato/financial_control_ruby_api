class Core::Tag::Finding < ApplicationSolidProcess
  deps do
    attribute :tag_repository, default: -> { Tag::Adapters.repository }

    validates :tag_repository, kind_of: Core::Tag::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_tag)
  end

  private

  def find_tag(user:, id:, **)
    case deps.tag_repository.find_by_id(user:, id:)
    in Solid::Success(tag:) then Continue(tag:)
    in Solid::Failure(type: :tag_not_found) then Failure(:tag_not_found)
    end
  end
end
