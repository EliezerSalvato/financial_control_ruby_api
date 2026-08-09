class Core::Institution::Creation < ApplicationSolidProcess
  deps do
    attribute :institution_repository, default: -> { Institution::Adapters.repository }

    validates :institution_repository, kind_of: Core::Institution::Repository::Interface
  end

  input do
    attribute :user
    attribute :name, :string
    attribute :logo_key, :string
    attribute :active, :boolean, default: true

    normalizes :name, with: ->(value) { value.strip }
    normalizes :logo_key, with: ->(value) { value.strip }

    validates :user, :name, :logo_key, presence: true
    validates :user, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:check_if_name_is_taken)
      .and_then(:create_institution)
  end

  private

  def check_if_name_is_taken(user:, name:, **)
    input.errors.add(:name, :taken) if deps.institution_repository.exists?(user:, name:)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def create_institution(user:, name:, logo_key:, active:, **)
    case deps.institution_repository.create(user:, attributes: { name:, logo_key:, active: })

    in Solid::Success(institution:) then Continue(institution:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :institution_creation_failed)

      Failure(:institution_creation_failed, input:)
    end
  end
end
