---
okf_version: "0.2"
---

# Architecture

* [Hexagonal boundary](architecture/hexagonal-boundary.md) - Money and identity change only inside Core processes; HTTP and Active Record stay at the edges.
* [Money and identity](architecture/money-and-identity.md) - Primary keys are UUIDv7, amounts are numeric(15,2), and names are unique per user ignoring case.

# Identity

* [Sessions](identity/sessions.md) - A short signed Bearer token plus a hashed refresh cookie; credential changes revoke refresh sessions only.

# Ledger

* [Accounts and cards](ledger/accounts-and-cards.md) - Cash and bank accounts, and credit cards whose billing cycle and limit move on settlement.
* [Transactions](ledger/transactions.md) - Income, expense, and transfer plans with a recurrence shape fixed at creation.
* [Occurrence projection](ledger/occurrence-projection.md) - A month's statement is a SQL projection of occurrences, not a stored table.
* [Settlements](ledger/settlements.md) - Daily processing posts due occurrences and card invoices in order, one open month at a time.
* [Imports](ledger/imports.md) - CSV rows become transactions through a preview, ordered rules, and one job per row.

# Months

* [Open months](months/open-months.md) - A user month stays open until every projected occurrence and card invoice is settled.
* [Goals](months/goals.md) - Category and tag budgets carry forward until goal_ends_on and are scored against the occurrence projection.

# Delivery

* [Jobs and notifications](delivery/jobs-and-notifications.md) - Solid Queue settles at 03:00 and retries month close at 05:00, notifying the user when work stays open.
* [HTTP surface](delivery/http-surface.md) - Versioned JSON under /api/v1, Bearer auth, stored locale, and Rack::Attack limits.
