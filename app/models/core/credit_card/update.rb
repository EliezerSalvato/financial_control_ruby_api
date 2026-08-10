class Core::CreditCard::Update < ApplicationSolidProcess
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
    attribute :id, :string
    attribute :institution_id, :string
    attribute :default_payment_account_id, :string
    attribute :name, :string
    attribute :total_limit, :decimal
    attribute :network, :string
    attribute :active, :boolean

    normalizes :name, with: ->(value) { value&.strip }
    normalizes :network, with: ->(value) { value&.strip }
    normalizes :institution_id, with: ->(value) { value&.strip.presence }
    normalizes :default_payment_account_id, with: ->(value) { value&.strip.presence }

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :name, :network, presence: true, allow_nil: true
    validates :institution_id, :default_payment_account_id, presence: true, allow_nil: true
    validates :total_limit, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_credit_card)
      .and_then(:adjust_available_limit)
      .and_then(:check_if_name_is_taken)
      .and_then(:check_if_institution_is_active)
      .and_then(:ensure_institution_belongs_to_user)
      .and_then(:check_if_default_payment_account_is_active)
      .and_then(:ensure_default_payment_account_belongs_to_user)
      .and_then(:update_credit_card)
  end

  private

  def find_credit_card(user:, id:, **)
    case deps.credit_card_repository.find_by_id(user:, id:)
    in Solid::Success(credit_card:) then Continue(credit_card:)
    in Solid::Failure(type: :credit_card_not_found)
      Failure(:credit_card_not_found)
    end
  end

  def adjust_available_limit(credit_card:, total_limit:, **)
    return Continue() if total_limit.nil?

    resulting_available = credit_card.available_limit + (total_limit - credit_card.total_limit)

    if resulting_available.negative?
      input.errors.add(:total_limit, :insufficient_available_limit)

      return Failure(:invalid_input, input:)
    end

    Continue(available_limit: resulting_available)
  end

  def check_if_name_is_taken(user:, name:, credit_card:, **)
    return Continue() if name.nil?

    input.errors.add(:name, :taken) if deps.credit_card_repository.exists?(user:, name:, excluding_id: credit_card.id)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def check_if_institution_is_active(user:, credit_card:, institution_id:, **)
    return Continue() if institution_id.blank?
    return Continue() if institution_id == credit_card.institution_id

    case deps.institution_repository.find_by_id(user:, id: institution_id)
    in Solid::Success(institution:)
      return Continue() if institution.active?

      input.errors.add(:institution_id, :inactive)

      Failure(:invalid_input, input:)
    in Solid::Failure(type: :institution_not_found)
      Continue()
    end
  end

  def ensure_institution_belongs_to_user(user:, credit_card:, institution_id:, **)
    target_institution_id = institution_id.presence || credit_card.institution_id
    return Continue() if target_institution_id.blank?

    case deps.institution_repository.find_by_id(user:, id: target_institution_id)
    in Solid::Success then Continue()
    in Solid::Failure(type: :institution_not_found)
      input.errors.add(:institution_id, :not_found)

      Failure(:invalid_input, input:)
    end
  end

  def check_if_default_payment_account_is_active(user:, credit_card:, default_payment_account_id:, **)
    return Continue() if default_payment_account_id.blank?
    return Continue() if default_payment_account_id == credit_card.default_payment_account_id

    case deps.account_repository.find_by_id(user:, id: default_payment_account_id)
    in Solid::Success(account:)
      return Continue() if account.active?

      input.errors.add(:default_payment_account_id, :inactive)

      Failure(:invalid_input, input:)
    in Solid::Failure(type: :account_not_found)
      Continue()
    end
  end

  def ensure_default_payment_account_belongs_to_user(user:, credit_card:, default_payment_account_id:, **)
    target_account_id = default_payment_account_id.presence || credit_card.default_payment_account_id
    return Continue() if target_account_id.blank?

    case deps.account_repository.find_by_id(user:, id: target_account_id)
    in Solid::Success then Continue()
    in Solid::Failure(type: :account_not_found)
      input.errors.add(:default_payment_account_id, :not_found)

      Failure(:invalid_input, input:)
    end
  end

  def update_credit_card(credit_card:, institution_id:, default_payment_account_id:, name:, total_limit:, network:, active:, available_limit: nil, **)
    attributes = {
      institution_id:,
      default_payment_account_id:,
      name:,
      total_limit:,
      available_limit:,
      network:,
      active:
    }.compact

    case deps.credit_card_repository.update(credit_card:, attributes:)
    in Solid::Success(credit_card:) then Continue(credit_card:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :credit_card_update_failed)

      Failure(:credit_card_update_failed, input:)
    end
  end
end
