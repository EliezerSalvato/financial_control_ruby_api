module Category
  extend Solid::Context

  self.actions = {
    list: Core::Category::Listing,
    find: Core::Category::Finding,
    create: Core::Category::Creation,
    update: Core::Category::Update,
    destroy: Core::Category::Deletion
  }
end
