module MonthlyStatus
  extend Solid::Context

  self.actions = {
    ensure_open: Core::MonthlyStatus::EnsureOpen,
    find: Core::MonthlyStatus::Finding,
    update: Core::MonthlyStatus::Update,
    close: Core::MonthlyStatus::Closing,
    close_open_months: Core::MonthlyStatus::OpenMonths::Closing,
    dispatch: Core::MonthlyStatus::Dispatching
  }
end
