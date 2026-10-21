---
type: Decision
title: Money and identity
description: Primary keys are UUIDv7, amounts are numeric(15,2), and names are unique per user ignoring case.
tags: [architecture, money]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: schema
    title: Database schema
    resource: db/schema.rb
  - id: user-record
    title: User::Record PaperTrail skip
    resource: app/models/user/record.rb
---

# Overview

Every domain table uses `uuid` primary keys defaulting to `uuidv7()`, so identifiers sort by creation time and are generated in PostgreSQL. Amounts are `numeric(15,2)`. A transaction amount is never negative; the [transaction kind](/ledger/transactions.md) decides whether settlement adds or subtracts.[^schema]

User-facing names (accounts, cards, categories, tags, institutions, import rules) are unique per `user_id` on `lower(name)`.

PostgreSQL enums carry the closed sets (`account_kind`, `transaction_kind`, `transaction_status`, `monthly_status`, and the import-rule enums). Check constraints repeat invariants the processes also enforce, so a bug in one layer cannot write a cash account that points at a bank, a canceled transaction with no `canceled_on`, or a transfer whose two accounts are the same.[^schema]

# Audit

PaperTrail (`versions`, uuid ids) records create/update/destroy on the domain records, including transactions, settlements, accounts, cards, goals, and monthly statuses. `User::Record` skips `password_digest`.[^user-record] Session token digests and password-reset tokens are not the audit subject.

# Dates that are not timestamps

`closing_day` and `due_day` are integers 1–31. `make_date_clamped` pins a day to the last day of a short month, which is how [card cycles](/ledger/accounts-and-cards.md) and the [occurrence projection](/ledger/occurrence-projection.md) stay defined in February.

[^schema]: `db/schema.rb` defines `uuidv7()` defaults, `numeric(15,2)` amounts, `lower(name)` unique indexes, enums, and the check constraints.
[^user-record]: `has_paper_trail skip: [:password_digest]` on `User::Record`.
