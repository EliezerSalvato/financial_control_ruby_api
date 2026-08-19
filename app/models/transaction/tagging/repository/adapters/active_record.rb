module Transaction::Tagging::Repository::Adapters::ActiveRecord
  include Core::Transaction::Tagging::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def sync(transaction:, tag_ids:)
    tag_ids = Array(tag_ids).uniq

    Transaction::Tagging::Record.where(transaction_id: transaction.id).where.not(tag_id: tag_ids).destroy_all

    tag_ids.each do |tag_id|
      record = Transaction::Tagging::Record.create_or_find_by(transaction_id: transaction.id, tag_id:)

      unless record.persisted?
        return Failure(:taggings_replace_failed, errors: Transaction::Tagging::Mapper.to_errors(record))
      end
    end

    Success(:taggings_replaced)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordNotFound
    Failure(:taggings_replace_failed, errors: Core::Errors.new)
  end
end
