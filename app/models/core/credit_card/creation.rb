class Core::CreditCard::Creation < ApplicationSolidProcess
  deps do
    attribute :credit_card_repository, default: -> { CreditCard::Adapters.repository }
    attribute :institution_repository, default: -> { Institution::Adapters.repository }
    attribute :account_repository, default: -> { Account::Adapters.repository }

    validates :credit_card_repository, kind_of: Core::CreditCard::Repository::Interface
    validates :institution_repository, kind_of: Core::Institution::Repository::Interface
    validates :account_repository, kind_of: Core::Account::Repository::Interface
  end

  input do
    attribute :user
    attribute :institution_id, :string
    attribute :default_payment_account_id, :string
    attribute :name, :string
    attribute :total_limit, :decimal, default: 0
    attribute :closing_day, :integer
    attribute :due_day, :integer
    attribute :network, :string
    attribute :active, :boolean, default: true

    normalizes :name, with: ->(value) { value.strip }
    normalizes :network, with: ->(value) { value.strip }
    normalizes :institution_id, with: ->(value) { value&.strip.presence }
    normalizes :default_payment_account_id, with: ->(value) { value&.strip.presence }

    validates :user, :institution_id, :default_payment_account_id, :name, :network, :closing_day, :due_day, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :closing_day, :due_day, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 31
    }
    validates :total_limit, numericality: { greater_than_or_equal_to: 0 }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:check_if_name_is_taken)
      .and_then(:check_if_institution_is_active)
      .and_then(:ensure_institution_belongs_to_user)
      .and_then(:check_if_default_payment_account_is_active)
      .and_then(:ensure_default_payment_account_belongs_to_user)
      .and_then(:create_credit_card)
  end

  private

  def check_if_name_is_taken(user:, name:, **)
    input.errors.add(:name, :taken) if deps.credit_card_repository.exists?(user:, name:)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def check_if_institution_is_active(user:, institution_id:, **)
    case deps.institution_repository.find_by_id(user:, id: institution_id)
    in Solid::Success(institution:)
      return Continue() if institution.active?

      input.errors.add(:institution_id, :inactive)

      Failure(:invalid_input, input:)
    in Solid::Failure(type: :institution_not_found)
      Continue()
    end
  end

  def ensure_institution_belongs_to_user(user:, institution_id:, **)
    case deps.institution_repository.find_by_id(user:, id: institution_id)
    in Solid::Success then Continue()
    in Solid::Failure(type: :institution_not_found)
      input.errors.add(:institution_id, :not_found)

      Failure(:invalid_input, input:)
    end
  end

  def check_if_default_payment_account_is_active(user:, default_payment_account_id:, **)
    case deps.account_repository.find_by_id(user:, id: default_payment_account_id)
    in Solid::Success(account:)
      return Continue() if account.active?

      input.errors.add(:default_payment_account_id, :inactive)

      Failure(:invalid_input, input:)
    in Solid::Failure(type: :account_not_found)
      Continue()
    end
  end

  def ensure_default_payment_account_belongs_to_user(user:, default_payment_account_id:, **)
    case deps.account_repository.find_by_id(user:, id: default_payment_account_id)
    in Solid::Success then Continue()
    in Solid::Failure(type: :account_not_found)
      input.errors.add(:default_payment_account_id, :not_found)

      Failure(:invalid_input, input:)
    end
  end

  def create_credit_card(user:, institution_id:, default_payment_account_id:, name:, total_limit:, closing_day:, due_day:, network:, active:, **)
    attributes = {
      institution_id:,
      default_payment_account_id:,
      name:,
      total_limit:,
      available_limit: total_limit,
      closing_day:,
      due_day:,
      network:,
      active:
    }

    case deps.credit_card_repository.create(user:, attributes:)
    in Solid::Success(credit_card:) then Continue(credit_card:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :credit_card_creation_failed)

      Failure(:credit_card_creation_failed, input:)
    end
  end
end
