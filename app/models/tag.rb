module Tag
  extend Solid::Context

  self.actions = {
    list: Core::Tag::Listing,
    find: Core::Tag::Finding,
    create: Core::Tag::Creation,
    change_goal: Core::Tag::Goal::Change,
    update: Core::Tag::Update,
    destroy: Core::Tag::Deletion
  }
end
