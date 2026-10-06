module Transaction
  extend Solid::Context

  self.actions = {
    list: Core::Transaction::Listing,
    find: Core::Transaction::Finding,
    create: Core::Transaction::Creation,
    change_recurrence: Core::Transaction::Recurrence::Change,
    update: Core::Transaction::Update,
    cancel: Core::Transaction::Cancellation,
    destroy: Core::Transaction::Deletion,
    settle: Core::Transaction::Settlement::Creation,
    list_settled: Core::Transaction::Settled::Listing,
    list_import_rules: Core::Transaction::Import::Rule::Listing,
    find_import_rule: Core::Transaction::Import::Rule::Finding,
    create_import_rule: Core::Transaction::Import::Rule::Creation,
    update_import_rule: Core::Transaction::Import::Rule::Update,
    destroy_import_rule: Core::Transaction::Import::Rule::Deletion,
    preview_import: Core::Transaction::Import::Preview,
    preview_import_row: Core::Transaction::Import::PreviewRow,
    confirm_import: Core::Transaction::Import::Confirmation,
    import_row: Core::Transaction::Import::PersistRow
  }
end
