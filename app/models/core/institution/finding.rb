class Core::Institution::Finding < ApplicationSolidProcess
  deps do
    attribute :institution_repository, default: -> { Institution::Adapters.repository }

    validates :institution_repository, kind_of: Core::Institution::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_institution)
  end

  private

  def find_institution(user:, id:, **)
    case deps.institution_repository.find_by_id(user:, id:)
    in Solid::Success(institution:) then Continue(institution:)
    in Solid::Failure(type: :institution_not_found) then Failure(:institution_not_found)
    end
  end
end
