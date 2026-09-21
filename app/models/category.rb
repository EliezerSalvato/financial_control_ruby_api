module Category
  extend Solid::Context

  self.actions = {
    list: Core::Category::Listing,
    find: Core::Category::Finding,
    create: Core::Category::Creation,
    change_goal: Core::Category::Goal::Change,
    update: Core::Category::Update,
    destroy: Core::Category::Deletion
  }
end
