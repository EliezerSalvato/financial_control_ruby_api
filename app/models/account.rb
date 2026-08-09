module Account
  extend Solid::Context

  self.actions = {
    list: Core::Account::Listing,
    find: Core::Account::Finding,
    create: Core::Account::Creation,
    update: Core::Account::Update,
    destroy: Core::Account::Deletion
  }
end
