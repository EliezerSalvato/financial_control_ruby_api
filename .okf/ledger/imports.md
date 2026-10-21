---
type: Process
title: Imports
description: CSV rows become transactions through a preview, ordered rules, and one job per row.
tags: [ledger]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: limits
    title: Core::Transaction::Import limits
    resource: app/models/core/transaction/import.rb
  - id: source-key
    title: Core::Transaction::Import::SourceKey
    resource: app/models/core/transaction/import/source_key.rb
  - id: confirmation
    title: Core::Transaction::Import::Confirmation
    resource: app/models/core/transaction/import/confirmation.rb
  - id: effects
    title: Import rule effect check constraints
    resource: db/schema.rb
---

# Overview

Import is two steps. `POST /api/v1/transactions/imports/previews` parses a CSV (at most 1 MB and 1000 rows), applies the user's active rules, and returns a preview the client can edit.[^limits] `POST /api/v1/transactions/imports` accepts that `import_id` and the edited rows, and enqueues one `PersistRowJob` per row.[^confirmation] Each job creates a normal [transaction](/ledger/transactions.md), so month-open, unpaid-invoice, category, and balance rules still apply. The preview does not write the ledger.

# Identity of a row

`source_key` is `date|description|amount` with two decimal places. A repeated line in the same file gets `|occurrence` starting at 2. The unique index on `(user_id, source_key)` where `source_key` is not null makes a replay skip the row that already landed.[^source-key]

# Rules

Rules are ordered by `position` and match `title`, `description`, or `both`, case-sensitive or not, with `contains` or `regex`. Effects run in their own `position` and are constrained per type:[^effects]

| Effect | Required payload |
|--------|------------------|
| `set_category` | `category_id` |
| `add_tags` | Non-empty `tag_ids` |
| `set_recurrence_type` | `recurrence_type` |
| `replace_text` | `pattern` and `replacement` |
| `set_installments_count` | A fixed count greater than 1, or a regex `pattern` that captures the count |
| `skip` | No text payload; the row is left out of the import |

A card import carries `credit_card_id` and `limit_consumption_type`. An account import carries `account_id` and leaves both card fields empty.

[^limits]: `Core::Transaction::Import::MAX_ROWS` is 1000 and `MAX_FILE_SIZE` is 1 megabyte.
[^source-key]: `Core::Transaction::Import::SourceKey.build`.
[^confirmation]: `Core::Transaction::Import::Confirmation#enqueue_rows`.
[^effects]: Check constraints on `transaction_import_rule_effects` in `db/schema.rb`.
