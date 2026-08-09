module Institution
  extend Solid::Context

  self.actions = {
    list: Core::Institution::Listing,
    find: Core::Institution::Finding,
    create: Core::Institution::Creation,
    update: Core::Institution::Update,
    destroy: Core::Institution::Deletion
  }
end
