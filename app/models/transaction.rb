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
    settle: Core::Transaction::Settlement::Creation
  }
end
