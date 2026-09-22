module Goal
  extend Solid::Context

  self.actions = {
    list: Core::Goal::Listing,
    list_targets: Core::Goal::Target::Listing
  }
end
