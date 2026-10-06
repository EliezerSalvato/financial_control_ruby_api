class Core::Transaction::Import::Preview < ApplicationSolidProcess
  deps do
    attribute :account_repository, default: -> { Account::Adapters.repository }
    attribute :credit_card_repository, default: -> { CreditCard::Adapters.repository }
    attribute :preview_row_job, default: -> { Transaction::Adapters.import_preview_row_job }

    validates :account_repository, kind_of: Core::Account::Repository::Interface
    validates :credit_card_repository, kind_of: Core::CreditCard::Repository::Interface
    validates :preview_row_job, kind_of: Core::Transaction::Import::PreviewRow::Job::Interface
  end

  input do
    attribute :user
    attribute :import_id, :string, default: -> { SecureRandom.uuid_v7 }
    attribute :filename, :string
    attribute :file, :string
    attribute :kind, :string
    attribute :payment_method, :string
    attribute :account_id, :string
    attribute :credit_card_id, :string
    attribute :limit_consumption_type, :string
    attribute :installments_count, :integer

    normalizes :filename, with: ->(value) { value&.strip.presence }
    normalizes :kind, :payment_method, :account_id, :credit_card_id, :limit_consumption_type, with: ->(value) { value&.strip.presence }

    validates :user, :file, :kind, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :kind, inclusion: { in: [ Core::Transaction::Kind::INCOME, Core::Transaction::Kind::EXPENSE ] }
    validates :payment_method, inclusion: { in: Core::Transaction::PaymentMethod::ALL }, allow_nil: true
    validates :limit_consumption_type, inclusion: { in: Core::Transaction::LimitConsumptionType::ALL }, allow_nil: true
    validates :installments_count, numericality: { only_integer: true, greater_than: 1 }, allow_nil: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:validate_file)
      .and_then(:validate_payment_method_compatibility)
      .and_then(:ensure_destination_belongs_to_user)
      .and_then(:parse_csv)
      .and_then(:enqueue_rows)
  end

  private

  def validate_file(filename:, file:, **)
    input.errors.add(:file, :invalid_file) unless filename.to_s.downcase.end_with?(".csv")
    input.errors.add(:file, :file_too_large) if file.bytesize > Core::Transaction::Import::MAX_FILE_SIZE

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def validate_payment_method_compatibility(kind:, payment_method:, **)
    Core::Transaction::PaymentMethod.validate_compatibility_with_kind(input.errors, kind:, payment_method:)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def ensure_destination_belongs_to_user(user:, payment_method:, account_id:, credit_card_id:, **)
    if payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD
      ensure_credit_card_belongs_to_user(user:, credit_card_id:)
    else
      ensure_account_belongs_to_user(user:, account_id:)
    end
  end

  def ensure_account_belongs_to_user(user:, account_id:)
    return required_field(:account_id) if account_id.blank?

    case deps.account_repository.find_by_id(user:, id: account_id)
    in Solid::Success(account:)
      return Continue() if account.active?

      reject(:account_id, :inactive)
    in Solid::Failure(type: :account_not_found)
      reject(:account_id, :not_found)
    end
  end

  def ensure_credit_card_belongs_to_user(user:, credit_card_id:)
    return required_field(:credit_card_id) if credit_card_id.blank?

    case deps.credit_card_repository.find_by_id(user:, id: credit_card_id)
    in Solid::Success(credit_card:)
      return Continue() if credit_card.active?

      reject(:credit_card_id, :inactive)
    in Solid::Failure(type: :credit_card_not_found)
      reject(:credit_card_id, :not_found)
    end
  end

  def required_field(attribute) = reject(attribute, :blank)

  def reject(attribute, error)
    input.errors.add(attribute, error)

    Failure(:invalid_input, input:)
  end

  def parse_csv(file:, **)
    case Core::Transaction::Import::CsvParsing.call(file:)
    in Solid::Success(rows:) then Continue(rows:)
    in Solid::Failure(input: nested_input)
      merge_nested_input_errors(nested_input)

      Failure(:invalid_input, input:)
    end
  end

  def enqueue_rows(user:, import_id:, rows:, kind:, payment_method:, account_id:, credit_card_id:, limit_consumption_type:, installments_count:, **)
    defaults = import_defaults(kind:, payment_method:, account_id:, credit_card_id:, limit_consumption_type:, installments_count:)
    occurrences = Hash.new(0)

    rows.each do |entry|
      key = occurrence_key(entry[:data])
      occurrences[key] += 1

      deps.preview_row_job.start(
        user_id: user.id, import_id:, row: entry[:row], data: entry[:data], occurrence: occurrences[key], defaults:
      )
    end

    Continue(import_id:, total_rows: rows.size)
  end

  def import_defaults(kind:, payment_method:, account_id:, credit_card_id:, limit_consumption_type:, installments_count:)
    if payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD
      { kind:, payment_method:, account_id: nil, credit_card_id:, limit_consumption_type:, installments_count: }
    else
      { kind:, payment_method:, account_id:, credit_card_id: nil, limit_consumption_type: nil, installments_count: }
    end
  end

  def occurrence_key(data)
    Core::Transaction::Import::SourceKey.raw_key(date: data["date"], description: data["description"], amount: data["amount"])
  end
end
