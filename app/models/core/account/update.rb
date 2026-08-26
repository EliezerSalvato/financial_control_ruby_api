class Core::Account::Update < ApplicationSolidProcess
  deps do
    attribute :account_repository, default: -> { Account::Adapters.repository }
    attribute :institution_repository, default: -> { Institution::Adapters.repository }

    validates :account_repository, kind_of: Core::Account::Repository::Interface
    validates :institution_repository, kind_of: Core::Institution::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string
    attribute :name, :string
    attribute :kind, :string
    attribute :institution_id, :string
    attribute :bank_account_type, :string
    attribute :current_balance, :decimal
    attribute :color, :string
    attribute :allow_negative_balance, :boolean
    attribute :active, :boolean

    normalizes :name, with: ->(value) { value&.strip }
    normalizes :color, with: ->(value) { value&.strip }
    normalizes :kind, with: ->(value) { value&.strip }
    normalizes :institution_id, with: ->(value) { value&.strip.presence }
    normalizes :bank_account_type, with: ->(value) { value&.strip.presence }

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :name, presence: true, allow_nil: true
    validates :kind, inclusion: { in: Core::Account::Kind::ALL }, allow_nil: true
    validates :color, presence: true, format: { with: Core::Color::FORMAT }, allow_nil: true
    validates :current_balance, numericality: true, allow_nil: true
    validates :bank_account_type, inclusion: { in: Core::Account::BankAccountType::ALL }, allow_nil: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_account)
      .and_then(:validate_kind_consistency)
      .and_then(:check_if_name_is_taken)
      .and_then(:check_if_institution_is_active)
      .and_then(:ensure_institution_belongs_to_user)
      .and_then(:update_account)
  end

  private

  def find_account(user:, id:, **)
    case deps.account_repository.find_by_id(user:, id:)
    in Solid::Success(account:) then Continue(account:)
    in Solid::Failure(type: :account_not_found)
      Failure(:account_not_found)
    end
  end

  def validate_kind_consistency(account:, kind:, institution_id:, bank_account_type:, **)
    resulting_kind = kind || account.kind

    case resulting_kind
    when Core::Account::Kind::BANK_ACCOUNT
      resulting_institution_id = institution_id.presence || account.institution_id
      resulting_bank_account_type = bank_account_type.presence || account.bank_account_type

      input.errors.add(:institution_id, :blank) if resulting_institution_id.blank?
      input.errors.add(:bank_account_type, :blank) if resulting_bank_account_type.blank?
    when Core::Account::Kind::CASH
      input.errors.add(:institution_id, :present) if institution_id.present?
      input.errors.add(:bank_account_type, :present) if bank_account_type.present?
    end

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue(resulting_kind:)
  end

  def check_if_name_is_taken(user:, name:, account:, **)
    return Continue() if name.nil?

    input.errors.add(:name, :taken) if deps.account_repository.exists?(user:, name:, excluding_id: account.id)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def check_if_institution_is_active(user:, account:, resulting_kind:, institution_id:, **)
    return Continue() unless resulting_kind == Core::Account::Kind::BANK_ACCOUNT
    return Continue() if institution_id.blank?
    return Continue() if institution_id == account.institution_id

    case deps.institution_repository.find_by_id(user:, id: institution_id)
    in Solid::Success(institution:)
      return Continue() if institution.active?

      input.errors.add(:institution_id, :inactive)

      Failure(:invalid_input, input:)
    in Solid::Failure(type: :institution_not_found)
      Continue()
    end
  end

  def ensure_institution_belongs_to_user(user:, account:, institution_id:, resulting_kind:, **)
    return Continue() unless resulting_kind == Core::Account::Kind::BANK_ACCOUNT

    target_institution_id = institution_id.presence || account.institution_id
    return Continue() if target_institution_id.blank?

    case deps.institution_repository.find_by_id(user:, id: target_institution_id)
    in Solid::Success then Continue()
    in Solid::Failure(type: :institution_not_found)
      input.errors.add(:institution_id, :not_found)

      Failure(:invalid_input, input:)
    end
  end

  def update_account(account:, name:, kind:, institution_id:, bank_account_type:, current_balance:, color:, allow_negative_balance:, active:, resulting_kind:, **)
    attributes = { name:, kind:, current_balance:, color:, allow_negative_balance:, active: }.compact

    if resulting_kind == Core::Account::Kind::CASH
      attributes[:institution_id] = nil
      attributes[:bank_account_type] = nil
    else
      attributes[:institution_id] = institution_id if institution_id.present?
      attributes[:bank_account_type] = bank_account_type if bank_account_type.present?
    end

    case deps.account_repository.update(account:, attributes:)
    in Solid::Success(account:) then Continue(account:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :account_update_failed)

      Failure(:account_update_failed, input:)
    end
  end
end
