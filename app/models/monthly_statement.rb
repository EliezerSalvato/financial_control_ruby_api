module MonthlyStatement
  extend Solid::Context

  self.actions = {
    list: Core::MonthlyStatement::Listing
  }
end
