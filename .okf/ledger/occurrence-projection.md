---
type: Model
title: Occurrence projection
description: A month's statement is a SQL projection of occurrences, not a stored table.
tags: [ledger, months, credit-card]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: listing-sql
    title: Monthly statement listing SQL
    resource: app/models/monthly_statement/listing.sql
  - id: occurrence-fn
    title: monthly_occurrence_on
    resource: db/schema.rb
---

# Overview

`GET /api/v1/monthly_statements` reads `MonthlyStatement::Record.for_period`, which runs `listing.sql`. Nothing is persisted as a statement row. The same projection feeds [settlement](/ledger/settlements.md), [month close](/months/open-months.md), and [goal](/months/goals.md) progress. Transfers are a second query (`listing_transfers.sql`) because a transfer has two accounts and no payment method.[^listing-sql]

# Two windows

| Branch | `payment_method` in the result | Window |
|--------|--------------------------------|--------|
| `transaction_for_credit_cards` | `credit_card` | The card's [billing cycle](/ledger/accounts-and-cards.md) for the requested month: opening through closing, with `due_date` |
| `transaction_for_accounts` | `account` | The calendar month. `pix`, `debit`, `boleto`, and the rest collapse to this one label. `due_date` is null |

`resource_id` is the card or the account. `resource_brand` is the card network, or the institution logo (falling back to the account color).

# Which amount, which day

`current_recurrence_on` is the day this plan occurs inside the window. `monthly_occurrence_on` projects the day-of-month of the first recurrence onto the window and clamps it: a day before opening moves into the next month, a day after closing lands on opening.[^occurrence-fn] The amount is the latest `transaction_recurrences` row with `starts_on <= closing_date`.

A one-time plan appears when that recurrence's `starts_on` is inside the window. An installment or recurring plan appears when the projected day sits inside the window and on or before `ends_on`, with one boundary case when the projected day falls on opening because the real end was the day before and the day-of-month did not match. A `canceled_on` drops every occurrence after that date.

The optional `:on` filter keeps rows whose `current_recurrence_on <= :on`. Settlement uses that to mean "due as of the reference date". `:statuses` filters the plan's status.

[^listing-sql]: `app/models/monthly_statement/listing.sql` unions the card branch and the account branch.
[^occurrence-fn]: `monthly_occurrence_on` in `db/schema.rb`.
