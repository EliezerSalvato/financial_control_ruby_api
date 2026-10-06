class Core::Transaction::Import::Confirmation < ApplicationSolidProcess
  deps do
    attribute :persist_row_job, default: -> { Transaction::Adapters.import_persist_row_job }

    validates :persist_row_job, kind_of: Core::Transaction::Import::PersistRow::Job::Interface
  end

  input do
    attribute :user
    attribute :import_id, :string
    attribute :rows, default: -> { [] }

    validates :user, :import_id, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :rows, kind_of: Array
  end

  def call(attributes)
    Given(attributes)
      .and_then(:validate_import_id)
      .and_then(:validate_rows)
      .and_then(:enqueue_rows)
  end

  private

  def validate_import_id(import_id:, **)
    input.errors.add(:import_id, :invalid) unless UUID.valid?(import_id)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def validate_rows(rows:, **)
    if rows.empty?
      input.errors.add(:rows, :blank)
    elsif rows.size > Core::Transaction::Import::MAX_ROWS
      input.errors.add(:rows, :too_many_rows, max: Core::Transaction::Import::MAX_ROWS)
    elsif rows.any? { |row| !row.is_a?(Hash) }
      input.errors.add(:rows, :invalid)
    end

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def enqueue_rows(user:, import_id:, rows:, **)
    rows.each { |row| deps.persist_row_job.start(user_id: user.id, import_id:, row:) }

    Continue(total_rows: rows.size)
  end
end
