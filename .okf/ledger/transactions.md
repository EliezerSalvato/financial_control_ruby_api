---
type: Model
title: Transactions
description: Income, expense, and transfer plans with a recurrence shape fixed at creation.
tags: [ledger, money]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: creation
    title: Core::Transaction::Creation
    resource: app/models/core/transaction/creation.rb
  - id: payment-method
    title: Core::Transaction::PaymentMethod
    resource: app/models/core/transaction/payment_method.rb
  - id: recurrence
    title: Core::Transaction::RecurrenceType
    resource: app/models/core/transaction/recurrence_type.rb
  - id: settlement
    title: Core::Transaction::Settlement::Creation
    resource: app/models/core/transaction/settlement/creation.rb
---

# Overview

A transaction is a plan, not a posted movement. Creation writes the header (`pending`), one subtype row, and the first `transaction_recurrences` row. [Settlement](/ledger/settlements.md) is what changes an [account balance or a card limit](/ledger/accounts-and-cards.md). The header's `value` is always `>= 0`.[^creation]

| Kind | Payment method | Subtype row |
|------|----------------|-------------|
| `income` | Required. `pix`, `ted`, `doc`, `deposit`, `cash`, `boleto` | `transaction_for_accounts` |
| `expense` | Required. Income methods plus `debit` and `credit_card` | Account row, or `transaction_for_credit_cards` when the method is `credit_card` |
| `transfer_between_accounts` | Must be absent | `transaction_for_transfer_between_accounts`, two different accounts |[^payment-method]

The category must belong to the user and be active. Tags must belong to the user. `source_key`, when present, is unique per user and is how [imports](/ledger/imports.md) stay idempotent.

# Recurrence

| Type | `ends_on` | `installments_count` |
|------|-----------|----------------------|
| `one_time` | Empty | Empty |
| `installment` | Required, on or after `starts_on`, and the month span must be greater than 1 | Computed from the span |
| `recurring` | Optional; when set, on or after `starts_on` | Empty |[^recurrence]

Later months store their own amount on `transaction_recurrences` (unique per transaction, month, year). The [occurrence projection](/ledger/occurrence-projection.md) uses the latest row whose `starts_on` is on or before the period's end.

# Status

New rows start `pending`. Settlement of a one-time plan sets `completed`. The first settlement of an installment or a recurring plan sets `active`; the installment becomes `completed` when the settled count equals `installments_count` and `occurred_on` has reached `ends_on`. A recurring plan stays `active`.[^settlement] Cancellation is allowed only from `active`, and it sets `canceled_on`. Occurrences after that date drop out of the projection.

# Card limit timing

`limit_consumption_type` applies only to `credit_card`. One-time plans are forced to `upfront`. Recurring plans are forced to `monthly`. Installments keep the caller's choice. On settlement, `monthly` consumes that occurrence's value. `upfront` on an installment consumes `value * installments_count` on installment 1 and `0` afterwards, so the whole purchase occupies limit immediately and each later invoice only releases its own slice.[^settlement]

Creation also refuses a closed [month](/months/open-months.md) and a card cycle that already has an invoice settlement. For a card, the month is the billing-cycle month of `starts_on`, not the calendar month.

[^creation]: `Core::Transaction::Creation` validates the month, the unpaid invoice, category, tags, and subtype before insert.
[^payment-method]: `Core::Transaction::PaymentMethod.validate_compatibility_with_kind`.
[^recurrence]: `Core::Transaction::RecurrenceType.validate_compatibility_with_ends_on`, matched by `transactions_recurrence_type_consistency`.
[^settlement]: `Core::Transaction::Settlement::Creation#next_status` and `#limit_consumed_for`.
