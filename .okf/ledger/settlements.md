---
type: Process
title: Settlements
description: Daily processing posts due occurrences and card invoices in order, one open month at a time.
tags: [ledger, months, jobs, credit-card]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: dispatching
    title: Core::Settlement::Dispatching
    resource: app/models/core/settlement/dispatching.rb
  - id: reference-date
    title: Core::Settlement::ReferenceDate
    resource: app/models/core/settlement/reference_date.rb
  - id: processing
    title: Core::Settlement::Processing
    resource: app/models/core/settlement/processing.rb
  - id: posting
    title: Core::Transaction::Settlement::Creation
    resource: app/models/core/transaction/settlement/creation.rb
---

# Overview

Production runs `Settlement::DailyDispatchJob` at 03:00 `America/Sao_Paulo`. Dispatch lists open [months](/months/open-months.md) up through the job's date and enqueues `Core::Settlement::Processing` per user-month that passes three gates.[^dispatching]

| Gate | Effect |
|------|--------|
| Previous month is still open | This month waits. Months settle in order. |
| A later month is already closed | This month is skipped. History does not reopen behind a close. |
| Reference date is before the month starts | Skipped. On the 1st, the current month's reference date is yesterday, so the current month waits until the 2nd. |[^reference-date]

For a past month the reference date is the month's last day. For the current month it is yesterday at dispatch time. A direct call must pass today or yesterday for the current month, and it rejects a future month.[^processing]

# What gets posted

Processing sets `monthly_statuses.processing`, then, in order:

1. Account occurrences from the [projection](/ledger/occurrence-projection.md) with status `pending` or `active` and `current_recurrence_on <= reference_date`, skipping pairs already in `transaction_settlements`.
2. Transfer occurrences, same rule.
3. Credit-card invoices due in that month whose `due_date <= reference_date` and not yet in `credit_card_invoice_settlements`.

Each item failure is recorded and the loop continues. At the end, `processing` is cleared, `last_processed_at` is set, and item failures become [notifications](/delivery/jobs-and-notifications.md). A validation failure or an unexpected error clears the flag and notifies too. `MonthlyStatusChannel` sees `processing` flip.

# Money movement

Posting an occurrence is idempotent on `(transaction_id, occurred_on)`. The repeat is `already_settled` and does not move money.[^posting]

| Subtype | Effect |
|---------|--------|
| Account income | Add `value` to the account |
| Account expense | Subtract `value` |
| Transfer | Subtract from the source, add to the destination |
| Credit card | Subtract `limit_consumed` from `available_limit`. The payment account moves later, when the [invoice](/ledger/accounts-and-cards.md) is paid |

`POST /api/v1/settlements/processing` runs the same process for one user-month. It does not bypass the gates.

[^dispatching]: `Core::Settlement::Dispatching#start_eligible`.
[^reference-date]: `Core::Settlement::ReferenceDate.for`.
[^processing]: `Core::Settlement::Processing#resolve_reference_date` and the three settle steps.
[^posting]: `Core::Transaction::Settlement::Creation#apply_financial_effects` returns early when `already_settled`.
