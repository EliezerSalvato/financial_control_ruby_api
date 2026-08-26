class Core::Account::Creation < ApplicationSolidProcess
  deps do
    attribute :account_repository, default: -> { Account::Adapters.repository }
    attribute :institution_repository, default: -> { Institution::Adapters.repository }

    validates :account_repository, kind_of: Core::Account::Repository::Interface
    validates :institution_repository, kind_of: Core::Institution::Repository::Interface
  end

  input do
    attribute :user
    attribute :name, :string
    attribute :kind, :string
    attribute :institution_id, :string
    attribute :bank_account_type, :string
    attribute :current_balance, :decimal, default: 0
    attribute :color, :string
    attribute :allow_negative_balance, :boolean, default: false
    attribute :active, :boolean, default: true

    normalizes :name, with: ->(value) { value.strip }
    normalizes :color, with: ->(value) { value.strip }
    normalizes :kind, with: ->(value) { value.strip }
    normalizes :institution_id, with: ->(value) { value&.strip.presence }
    normalizes :bank_account_type, with: ->(value) { value&.strip.presence }

    validates :user, :name, :kind, :color, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :kind, inclusion: { in: Core::Account::Kind::ALL }
    validates :color, format: { with: Core::Color::FORMAT }
    validates :current_balance, numericality: true
    validates :institution_id, :bank_account_type, presence: true, if: -> { kind == Core::Account::Kind::BANK_ACCOUNT }
    validates :institution_id, :bank_account_type, absence: true, if: -> { kind == Core::Account::Kind::CASH }
    validates :bank_account_type, inclusion: { in: Core::Account::BankAccountType::ALL }, allow_nil: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:check_if_name_is_taken)
      .and_then(:check_if_institution_is_active)
      .and_then(:ensure_institution_belongs_to_user)
      .and_then(:create_account)
  end

  private

  def check_if_name_is_taken(user:, name:, **)
    input.errors.add(:name, :taken) if deps.account_repository.exists?(user:, name:)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def check_if_institution_is_active(user:, kind:, institution_id:, **)
    return Continue() unless kind == Core::Account::Kind::BANK_ACCOUNT
    return Continue() if institution_id.blank?

    case deps.institution_repository.find_by_id(user:, id: institution_id)
    in Solid::Success(institution:)
      return Continue() if institution.active?

      input.errors.add(:institution_id, :inactive)

      Failure(:invalid_input, input:)
    in Solid::Failure(type: :institution_not_found)
      Continue()
    end
  end

  def ensure_institution_belongs_to_user(user:, kind:, institution_id:, **)
    return Continue() unless kind == Core::Account::Kind::BANK_ACCOUNT
    return Continue() if institution_id.blank?

    case deps.institution_repository.find_by_id(user:, id: institution_id)
    in Solid::Success then Continue()
    in Solid::Failure(type: :institution_not_found)
      input.errors.add(:institution_id, :not_found)

      Failure(:invalid_input, input:)
    end
  end

  def create_account(user:, name:, kind:, institution_id:, bank_account_type:, current_balance:, color:, allow_negative_balance:, active:, **)
    attributes = {
      name:,
      kind:,
      institution_id:,
      bank_account_type:,
      current_balance:,
      color:,
      allow_negative_balance:,
      active:
    }

    case deps.account_repository.create(user:, attributes:)
    in Solid::Success(account:) then Continue(account:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :account_creation_failed)

      Failure(:account_creation_failed, input:)
    end
  end
end
