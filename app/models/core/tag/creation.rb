class Core::Tag::Creation < ApplicationSolidProcess
  deps do
    attribute :tag_repository, default: -> { Tag::Adapters.repository }

    validates :tag_repository, kind_of: Core::Tag::Repository::Interface
  end

  input do
    attribute :user
    attribute :name, :string
    attribute :color, :string
    attribute :active, :boolean, default: true

    normalizes :name, with: ->(value) { value.strip }
    normalizes :color, with: ->(value) { value.strip }

    validates :user, :name, :color, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :color, format: { with: Core::Color::FORMAT }
  end


  def call(attributes)
    Given(attributes)
      .and_then(:check_if_name_is_taken)
      .and_then(:create_tag)
  end

  private

  def check_if_name_is_taken(user:, name:, **)
    input.errors.add(:name, :taken) if deps.tag_repository.exists?(user:, name:)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def create_tag(user:, name:, color:, active:, **)
    case deps.tag_repository.create(user:, attributes: { name:, color:, active: })

    in Solid::Success(tag:) then Continue(tag:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :tag_creation_failed)

      Failure(:tag_creation_failed, input:)
    end
  end
end
