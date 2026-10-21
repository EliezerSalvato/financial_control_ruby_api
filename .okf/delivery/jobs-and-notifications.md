---
type: Process
title: Jobs and notifications
description: Solid Queue settles at 03:00 and retries month close at 05:00, notifying the user when work stays open.
tags: [jobs, months]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: recurring
    title: Production recurring jobs
    resource: config/recurring.yml
  - id: settlement-kinds
    title: Settlement failure notification kinds
    resource: app/models/core/settlement/processing/failure_notifying.rb
  - id: closing-kinds
    title: Month-close notification kinds
    resource: app/models/core/monthly_status/closing/validation_error_notifying.rb
---

# Overview

The `jobs` Compose service runs Solid Queue. Production schedules, in `America/Sao_Paulo`:[^recurring]

| Schedule | Job | Effect |
|----------|-----|--------|
| 03:00 every day | `Settlement::DailyDispatchJob` | Enqueue [settlement](/ledger/settlements.md) for eligible open months |
| 05:00 on the 1st | `MonthlyStatus::MonthlyDispatchJob` | Enqueue [month close](/months/open-months.md) for users with an open month through the previous month. A user who stays open is retried at 05:00 on later days of that same month. |
| Every hour at minute 12 | `SolidQueue::Job.clear_finished_in_batches` | Drop finished job rows |

Mission Control is mounted at `/jobs` with HTTP basic auth (`MISSION_CONTROL_HTTP_BASIC_AUTH_*`). Import preview and persist, settlement processing, and month close each have their own job class. A `Solid::Failure` from dispatch or close raises `RetryableError` so the queue retries.

# Notifications

In-app notifications are rows on `notifications`, scoped to `user_id`. While unread, a partial unique index on `(user_id, kind, notifiable_type, notifiable_id, dedup_key)` collapses duplicates. `NotificationChannel` pushes `{ kind, notification, unread_count }` for one item, or `{ kind, unread_count }` for a batch.

| Kind | When |
|------|------|
| `transaction.validation.errors` | One occurrence failed inside a settlement run |
| `credit_card_invoice.validation.errors` | One invoice failed inside a settlement run |
| `settlement.errors` | The settlement run itself failed, or the batch of item failures |
| `monthly_status.closing.errors` | One or more months stayed open or failed to close |
| `monthly_status.errors` | The close run itself raised |[^settlement-kinds][^closing-kinds]

`POST /api/v1/notifications/:id/read` and `POST /api/v1/notifications/read_all` mark rows read. Reading clears the dedup slot, so a later failure of the same subject can notify again.

[^recurring]: `config/recurring.yml` under `production`.
[^settlement-kinds]: Kinds emitted by `Core::Settlement::Processing::FailureNotifying` and `ValidationErrorNotifying`.
[^closing-kinds]: Kinds emitted by `Core::MonthlyStatus::Closing::ValidationErrorNotifying` and `UnexpectedErrorNotifying`.
