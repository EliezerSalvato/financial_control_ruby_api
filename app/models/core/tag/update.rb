class Core::Tag::Update < ApplicationSolidProcess
  deps do
    attribute :tag_repository, default: -> { Tag::Adapters.repository }

    validates :tag_repository, kind_of: Core::Tag::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string
    attribute :name, :string
    attribute :color, :string
    attribute :active, :boolean

    normalizes :name, with: ->(value) { value&.strip }
    normalizes :color, with: ->(value) { value&.strip }

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :name, presence: true, allow_nil: true
    validates :color, presence: true, format: { with: Core::Color::FORMAT }, allow_nil: true
  end


  def call(attributes)
    Given(attributes)
      .and_then(:find_tag)
      .and_then(:check_if_name_is_taken)
      .and_then(:update_tag)
  end

  private

  def find_tag(user:, id:, **)
    case deps.tag_repository.find_by_id(user:, id:)
    in Solid::Success(tag:) then Continue(tag:)
    in Solid::Failure(type: :tag_not_found)
      Failure(:tag_not_found)
    end
  end

  def check_if_name_is_taken(user:, name:, tag:, **)
    return Continue() if name.nil?

    input.errors.add(:name, :taken) if deps.tag_repository.exists?(user:, name:, excluding_id: tag.id)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def update_tag(tag:, name:, color:, active:, **)
    attributes = { name:, color:, active: }.compact


    case deps.tag_repository.update(tag:, attributes:)
    in Solid::Success(tag:) then Continue(tag:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :tag_update_failed)

      Failure(:tag_update_failed, input:)
    end
  end
end
