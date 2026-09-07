module Settlement
  extend Solid::Context

  self.actions = {
    process: Core::Settlement::Processing,
    dispatch: Core::Settlement::Dispatching
  }
end
