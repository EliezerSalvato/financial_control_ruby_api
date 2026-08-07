class Core::Category::Update < ApplicationSolidProcess
  deps do
    attribute :category_repository, default: -> { Category::Adapters.repository }

    validates :category_repository, kind_of: Core::Category::Repository::Interface
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
    validates :color, presence: true, format: { with: Core::Category::Color::FORMAT }, allow_nil: true
  end


  def call(attributes)
    Given(attributes)
      .and_then(:find_category)
      .and_then(:check_if_name_is_taken)
      .and_then(:update_category)
  end

  private

  def find_category(user:, id:, **)
    case deps.category_repository.find_by_id(user:, id:)
    in Solid::Success(category:) then Continue(category:)
    in Solid::Failure(type: :category_not_found)
      Failure(:category_not_found)
    end
  end

  def check_if_name_is_taken(user:, name:, category:, **)
    return Continue() if name.nil?

    input.errors.add(:name, :taken) if deps.category_repository.exists?(user:, name:, excluding_id: category.id)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def update_category(category:, name:, color:, active:, **)
    attributes = { name:, color:, active: }.compact


    case deps.category_repository.update(category:, attributes:)
    in Solid::Success(category:) then Continue(category:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :category_update_failed)

      Failure(:category_update_failed, input:)
    end
  end
end
