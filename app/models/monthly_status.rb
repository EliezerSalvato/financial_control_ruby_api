module MonthlyStatus
  extend Solid::Context

  self.actions = {
    ensure_open: Core::MonthlyStatus::EnsureOpen,
    find: Core::MonthlyStatus::Finding,
    update: Core::MonthlyStatus::Update
  }
end
