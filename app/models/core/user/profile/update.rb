class Core::User::Profile::Update < ApplicationSolidProcess
  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
  end

  input do
    attribute :user
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :configs

    normalizes :first_name, :last_name, with: ->(value) { value&.strip }

    validates :user, presence: true, kind_of: Core::User::Entity
    validates :first_name, :last_name, presence: true, allow_nil: true
    validates :configs, kind_of: Hash, allow_nil: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:ensure_something_to_update)
      .and_then(:update_profile)
  end

  private

  def ensure_something_to_update(first_name: nil, last_name: nil, configs: nil, **)
    return Continue() if first_name.present? || last_name.present? || !configs.nil?

    input.errors.add(:base, :at_least_one_attribute)
    Failure(:invalid_input, input:)
  end

  def update_profile(user:, first_name: nil, last_name: nil, configs: nil, **)
    configs = merge_configs(user.configs, configs) unless configs.nil?

    case deps.user_repository.update_profile(user:, first_name:, last_name:, configs:)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)

      Failure(:profile_update_failed, input:)
    end
  end

  def merge_configs(current, incoming)
    stringify_configs(current).merge(stringify_configs(incoming))
  end

  def stringify_configs(value)
    hash = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
    hash.deep_stringify_keys
  end
end
