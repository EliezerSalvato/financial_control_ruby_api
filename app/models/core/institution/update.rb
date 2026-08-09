class Core::Institution::Update < ApplicationSolidProcess
  deps do
    attribute :institution_repository, default: -> { Institution::Adapters.repository }

    validates :institution_repository, kind_of: Core::Institution::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string
    attribute :name, :string
    attribute :logo_key, :string
    attribute :active, :boolean

    normalizes :name, with: ->(value) { value&.strip }
    normalizes :logo_key, with: ->(value) { value&.strip.presence }

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :name, presence: true, allow_nil: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_institution)
      .and_then(:check_if_name_is_taken)
      .and_then(:update_institution)
  end

  private

  def find_institution(user:, id:, **)
    case deps.institution_repository.find_by_id(user:, id:)
    in Solid::Success(institution:) then Continue(institution:)
    in Solid::Failure(type: :institution_not_found)
      Failure(:institution_not_found)
    end
  end

  def check_if_name_is_taken(user:, name:, institution:, **)
    return Continue() if name.nil?

    input.errors.add(:name, :taken) if deps.institution_repository.exists?(user:, name:, excluding_id: institution.id)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def update_institution(institution:, name:, logo_key:, active:, **)
    attributes = { name:, logo_key:, active: }.compact

    case deps.institution_repository.update(institution:, attributes:)
    in Solid::Success(institution:) then Continue(institution:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :institution_update_failed)

      Failure(:institution_update_failed, input:)
    end
  end
end
