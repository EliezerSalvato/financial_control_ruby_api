---
type: Model
title: Goals
description: Category and tag budgets carry forward until goal_ends_on and are scored against the occurrence projection.
tags: [months, ledger]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: targets-sql
    title: Goal target listing SQL
    resource: app/models/goal/listing_targets.sql
  - id: listing-sql
    title: Goal progress listing SQL
    resource: app/models/goal/listing.sql
---

# Overview

A goal is a monthly budget on a category or a tag, not a third ledger. `category_goals` and `tag_goals` store `(month, year, value)` with `value >= 0`, unique per parent and period. `goal_ends_on` on the category or tag is the last date the series applies.[^targets-sql]

`GET /api/v1/goals/targets` returns the budget in force for the requested month. The value is the latest goal row whose year/month is less than or equal to that month. A category with a goal in January and none in February still reports the January amount in February, until `goal_ends_on` is before the first day of the requested month. The same rule applies to tags. Changing goals is `PATCH /categories/:id/goals` and `PATCH /tags/:id/goals`, which write that month's row.

# Progress

`GET /api/v1/goals` lists the [occurrence projection](/ledger/occurrence-projection.md) for the month (statements and transfers) and attaches each plan's `category_id` and `tag_ids`.[^listing-sql] Spent-versus-budget is that join: the client, or a later reader, sums occurrence values onto the targets. Transfers are included in the progress query because they are occurrences of a categorized plan.

[^targets-sql]: `app/models/goal/listing_targets.sql` picks the latest `category_goals` or `tag_goals` row at or before the period.
[^listing-sql]: `app/models/goal/listing.sql` unions statement and transfer occurrences and aggregates `transaction_tags`.
