---
type: Model
title: Accounts and cards
description: Cash and bank accounts, and credit cards whose billing cycle and limit move on settlement.
tags: [ledger, money, credit-card]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: schema
    title: accounts and credit_cards constraints
    resource: db/schema.rb
  - id: billing-cycle
    title: credit_card_billing_cycle_dates
    resource: db/schema.rb
  - id: invoice-creation
    title: Core::CreditCard::InvoiceSettlement::Creation
    resource: app/models/core/credit_card/invoice_settlement/creation.rb
---

# Overview

An account is either `cash` or `bank_account`. A bank account stores `institution_id` and `bank_account_type` (`checking`, `savings`, `investment`, `salary`). A cash account stores neither. `current_balance` starts at the value given on creation and later moves only when a [settlement](/ledger/settlements.md) posts. `allow_negative_balance` defaults to false; the check that blocks a negative balance lives with the adjustment, and the flag is the escape hatch.[^schema]

A credit card belongs to an institution and to a `default_payment_account_id`. It stores `total_limit`, `available_limit` (always `<= total_limit`), `closing_day`, `due_day`, `network`, and `allow_negative_available_limit`. Creating a card purchase does not touch `available_limit`. The limit drops when the purchase's occurrence is settled, and it comes back when the invoice is paid.[^invoice-creation]

# Billing cycle

`credit_card_billing_cycle_dates(card, month, year)` returns `opening_date`, `closing_date`, and `due_date` for the invoice whose due date falls in that calendar month.[^billing-cycle]

| Step | Rule |
|------|------|
| Closing month | The requested month, or the previous month when `closing_day > due_day` |
| Closing date | `closing_day` in that month, clamped to the month's last day |
| Due date | `due_day` in the requested month, clamped the same way |
| Opening date | The day after the previous cycle's closing date |

A purchase date is mapped to a cycle by testing the current month and the next two. That cycle's month/year is the [open month](/months/open-months.md) the purchase must belong to, which can differ from the calendar month of `starts_on`.

# Invoice payment

Paying an invoice writes `credit_card_invoice_settlements` (unique on card + `due_date`), subtracts `total_value` from the payment account, adds `released_limit` (stored equal to `total_value`) back onto `available_limit`, and links the cycle's card settlements to that invoice. A second pay of the same due date is an already-settled success and does not move money again.[^invoice-creation]

[^schema]: `accounts_kind_consistency` and `credit_cards_available_limit_within_total` in `db/schema.rb`.
[^billing-cycle]: Function `credit_card_billing_cycle_dates` in `db/schema.rb`, using `make_date_clamped`.
[^invoice-creation]: `Core::CreditCard::InvoiceSettlement::Creation` debits the payment account and releases limit only when `already_settled` is false.
