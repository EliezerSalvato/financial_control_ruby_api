---
type: Process
title: Open months
description: A user month stays open until every projected occurrence and card invoice is settled.
tags: [months, jobs]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: ensure-open
    title: Core::MonthlyStatus::EnsureOpen
    resource: app/models/core/monthly_status/ensure_open.rb
  - id: closing
    title: Core::MonthlyStatus::Closing
    resource: app/models/core/monthly_status/closing.rb
  - id: open-months-closing
    title: Core::MonthlyStatus::OpenMonths::Closing
    resource: app/models/core/monthly_status/open_months/closing.rb
---

# Overview

`monthly_statuses` has one row per user, month, and year. It is created lazily the first time a [transaction](/ledger/transactions.md) or a [settlement](/ledger/settlements.md) needs it, with `status = open`. Creating a missing month fails when any later month for that user is already closed, so a gap cannot appear behind a close.[^ensure-open]

For an account or a transfer, the month is the calendar month of the date. For a credit card, it is the [billing-cycle](/ledger/accounts-and-cards.md) month. A write into a `closed` month fails with `monthly_status_closed`.

# Closing

`Core::MonthlyStatus::Closing` refuses the current month and any future month. It loads the [occurrence projection](/ledger/occurrence-projection.md) and the transfer list, and it closes only when both of these are empty:[^closing]

- Account and transfer occurrences with no `transaction_settlements` row for `(id, current_recurrence_on)`.
- Distinct `(credit_card_id, due_date)` pairs from card lines with no `credit_card_invoice_settlements` row.

Otherwise it returns `monthly_status_kept_open` plus the pending lists. That success is intentional: the month is not broken, it is unfinished.

On the 1st at 05:00, `MonthlyStatus::MonthlyDispatchJob` enqueues a close for every user who still has an open month up through the previous month. The per-user process ensures the previous month exists, tries to close every open month up through it, and notifies the user about months that stayed open. If any stayed open and tomorrow is still the same calendar month, it reschedules itself for tomorrow at 05:00. It does not roll the retry into the next month.[^open-months-closing]

`PATCH /api/v1/monthly_statuses` can set the status directly. `processing` and `last_processed_at` are settlement bookkeeping, broadcast on `MonthlyStatusChannel` for that month and year. A subscription is rejected when the row does not exist.

[^ensure-open]: `Core::MonthlyStatus::EnsureOpen` resolves the reference month, creates the row, and rejects `closed`.
[^closing]: `Core::MonthlyStatus::Closing#close_month` and `#reject_current_or_future_month`.
[^open-months-closing]: `Core::MonthlyStatus::OpenMonths::Closing` notifies `still_open` and reschedules at hour 5 only while `tomorrow.month == today.month`.
