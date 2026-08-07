module Tag
  extend Solid::Context

  self.actions = {
    list: Core::Tag::Listing,
    find: Core::Tag::Finding,
    create: Core::Tag::Creation,
    update: Core::Tag::Update,
    destroy: Core::Tag::Deletion
  }
end
