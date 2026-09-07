module CreditCard
  extend Solid::Context

  self.actions = {
    list: Core::CreditCard::Listing,
    find: Core::CreditCard::Finding,
    create: Core::CreditCard::Creation,
    update: Core::CreditCard::Update,
    destroy: Core::CreditCard::Deletion,
    settle_invoice: Core::CreditCard::InvoiceSettlement::Creation,
    ensure_invoice_unpaid: Core::CreditCard::InvoiceSettlement::EnsureUnpaid
  }
end
