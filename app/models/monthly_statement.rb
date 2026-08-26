module MonthlyStatement
  extend Solid::Context

  self.actions = {
    list: Core::MonthlyStatement::Listing,
    list_transfers: Core::MonthlyStatement::ListingTransfers
  }
end
