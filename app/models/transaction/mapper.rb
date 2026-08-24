module Transaction::Mapper
  extend self

  def to_entity(record, include_associations: true)
    return if record.nil?

    Core::Transaction::Entity.new(
      id: record.id,
      user_id: record.user_id,
      category_id: record.category_id,
      description: record.description,
      kind: record.kind,
      status: record.status,
      payment_method: record.payment_method,
      recurrence_type: record.recurrence_type,
      installments_count: record.installments_count,
      ends_on: record.ends_on,
      canceled_on: record.canceled_on,
      **contextual_attributes(record, include_associations:),
      recurrences: record.recurrences.sort_by(&:starts_on).map { |recurrence| Transaction::Recurrence::Mapper.to_entity(recurrence) }
    )
  end

  def to_entities(records, include_associations: false)
    records.map { |record| to_entity(record, include_associations:) }
  end

  def to_record(entity)
    Transaction::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end

  def contextual_attributes(record, include_associations:)
    return {} unless include_associations

    associations = { tag_ids: record.taggings.map(&:tag_id) }

    if record.payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD
      associations.merge(
        credit_card_id: record.for_credit_card&.credit_card_id,
        limit_consumption_type: record.for_credit_card&.limit_consumption_type
      )
    elsif record.kind == Core::Transaction::Kind::TRANSFER_BETWEEN_ACCOUNTS
      associations.merge(
        source_account_id: record.for_transfer_between_accounts&.source_account_id,
        destination_account_id: record.for_transfer_between_accounts&.destination_account_id
      )
    else
      associations.merge(account_id: record.for_account&.account_id)
    end
  end
  private_class_method :contextual_attributes
end
