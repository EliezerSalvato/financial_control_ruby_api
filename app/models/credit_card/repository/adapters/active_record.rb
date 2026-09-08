module CreditCard::Repository::Adapters::ActiveRecord
  include Core::CreditCard::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list(user:, filters:, sorting:, page:, per_page:)
    scope = user_credit_cards(user)
    sorts = sorting.to_s.split(",").map(&:strip)
    query = scope.ransack(filters.merge(s: sorts))
    records, pagination = Pagination.paginate(query.result, page:, per_page:)

    Success(:credit_cards_listed, credit_cards: CreditCard::Mapper.to_entities(records), pagination:)
  rescue Ransack::InvalidSearchError, ArgumentError, Pagy::OptionError
    Failure(:invalid_filters)
  end

  def find_by_id(user:, id:)
    credit_card = user_credit_cards(user).find_by(id:)

    return Success(:credit_card_found, credit_card: CreditCard::Mapper.to_entity(credit_card)) if credit_card.present?

    Failure(:credit_card_not_found)
  end

  def exists?(user:, name:, excluding_id: nil)
    scope = user_credit_cards(user).where("LOWER(name) = LOWER(?)", name)
    scope = scope.where.not(id: excluding_id) if excluding_id.present?

    scope.exists?
  end

  def create(user:, attributes:)
    credit_card = user_credit_cards(user).create(attributes)

    return Success(:credit_card_created, credit_card: CreditCard::Mapper.to_entity(credit_card)) if credit_card.persisted?

    Failure(
      :credit_card_creation_failed,
      credit_card: CreditCard::Mapper.to_entity(credit_card),
      errors: CreditCard::Mapper.to_errors(credit_card)
    )
  end

  def update(credit_card:, attributes:)
    record = CreditCard::Mapper.to_record(credit_card)
    record.lock!
    record.reload
    updated = record.update(attributes)

    return Success(:credit_card_updated, credit_card: CreditCard::Mapper.to_entity(record)) if updated

    Failure(
      :credit_card_update_failed,
      credit_card: CreditCard::Mapper.to_entity(record),
      errors: CreditCard::Mapper.to_errors(record)
    )
  end

  def destroy(credit_card:)
    record = CreditCard::Mapper.to_record(credit_card)

    return Success(:credit_card_destroyed) if record.destroy

    Failure(:credit_card_destruction_failed)
  end

  def adjust_available_limit(credit_card:, amount:, operation:)
    ApplicationRecord.transaction do
      record = CreditCard::Mapper.to_record(credit_card)
      record.lock!
      record.reload

      delta = operation == Core::CreditCard::AvailableLimitOperation::SUBTRACT ? -amount : amount
      new_limit = record.available_limit + delta

      if new_limit.negative? && !record.allow_negative_available_limit?
        Failure(
          :insufficient_available_limit,
          credit_card: CreditCard::Mapper.to_entity(record),
          errors: Core::Errors.new(available_limit: [ I18n.t("credit_card.errors.insufficient_available_limit") ])
        )
      elsif new_limit > record.total_limit
        Failure(
          :available_limit_exceeds_total_limit,
          credit_card: CreditCard::Mapper.to_entity(record),
          errors: Core::Errors.new(available_limit: [ I18n.t("credit_card.errors.available_limit_exceeds_total_limit") ])
        )
      elsif record.update(available_limit: new_limit)
        Success(:credit_card_available_limit_adjusted, credit_card: CreditCard::Mapper.to_entity(record))
      else
        Failure(
          :credit_card_available_limit_adjustment_failed,
          credit_card: CreditCard::Mapper.to_entity(record),
          errors: CreditCard::Mapper.to_errors(record)
        )
      end
    end
  end

  def billing_cycle_month(user:, credit_card_id:, date:)
    return Failure(:credit_card_not_found) unless user_credit_cards(user).exists?(id: credit_card_id)

    invoice_month_candidates(date).each do |month, year|
      cycle = billing_cycle_dates(credit_card_id, month, year)

      next if cycle.blank?

      opening_date = cast_date(cycle.opening_date)
      closing_date = cast_date(cycle.closing_date)

      next unless (opening_date..closing_date).cover?(date)

      return Success(:credit_card_billing_cycle_month_resolved, month:, year:)
    end

    Success(:credit_card_billing_cycle_month_resolved, month: date.month, year: date.year)
  end

  private

  def user_credit_cards(user)
    CreditCard::Record.where(user_id: user.id)
  end

  def invoice_month_candidates(date)
    current = Date.new(date.year, date.month, 1)

    [ current, current.next_month, current.next_month.next_month ].map { |cursor| [ cursor.month, cursor.year ] }
  end

  def billing_cycle_dates(credit_card_id, month, year)
    sql = <<~SQL
      SELECT opening_date, closing_date
        FROM credit_card_billing_cycle_dates(:credit_card_id, :month, :year)
    SQL

    CreditCard::Record.find_by_sql([ sql, { credit_card_id:, month:, year: } ]).first
  end

  def cast_date(value)
    value.is_a?(Date) ? value : Date.parse(value.to_s)
  end
end
