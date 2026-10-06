module Transaction::Import::Broadcast
  extend self

  PREVIEW = "preview"
  IMPORT = "import"

  def stream_target(user_id) = user_id

  def preview_processed(user_id:, import_id:, row:, data:)
    publish(user_id:, import_id:, stage: PREVIEW, row:, status: "processed", data:)
  end

  def preview_skipped(user_id:, import_id:, row:)
    publish(user_id:, import_id:, stage: PREVIEW, row:, status: "skip")
  end

  def import_created(user_id:, import_id:, row:, transaction_id:)
    publish(user_id:, import_id:, stage: IMPORT, row:, status: "created", transaction_id:)
  end

  def import_ignored(user_id:, import_id:, row:)
    publish(user_id:, import_id:, stage: IMPORT, row:, status: "ignored")
  end

  def import_skipped(user_id:, import_id:, row:)
    publish(user_id:, import_id:, stage: IMPORT, row:, status: "skip")
  end

  def error(user_id:, import_id:, stage:, row:, input: nil)
    message = I18n.with_locale(locale_for(user_id)) do
      input ? input.errors.full_messages.to_sentence : I18n.t("transaction.import.errors.unexpected")
    end

    publish(user_id:, import_id:, stage:, row:, status: "error", error: message)
  end

  private

  def publish(user_id:, **payload)
    TransactionImportChannel.broadcast_to(stream_target(user_id), payload)
  end

  def locale_for(user_id)
    Core::User::Locale.for(user_id:, user_repository: User::Adapters.repository)
  end
end
