---
type: Decision
title: Hexagonal boundary
description: Money and identity change only inside Core processes; HTTP and Active Record stay at the edges.
tags: [architecture]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: registration
    title: Core::User::Registration
    resource: app/models/core/user/registration.rb
  - id: user-facade
    title: User facade
    resource: app/models/user.rb
---

# Overview

Each bounded context mirrors `User`. A `Solid::Context` facade (`User.register`, `Transaction.create`) is the only call surface for HTTP. The process under `app/models/core/` declares `deps` and `input`, depends on a `Core::…::Interface`, and orchestrates with `.and_then`. Adapters in `app/models/<context>/**/adapters/` implement those interfaces and are wired from `<Context>::Adapters`.[^registration]

`*::Record` is persistence: `self.table_name`, constraints, and PaperTrail. `Core::*::Entity` (`Data.define`) is what crosses the boundary. Mappers convert both ways. `current_user` is a `Core::User::Entity`. Controllers authenticate, pass strong params and `request_metadata`, pattern-match `Solid::Success` / `Solid::Failure`, and render. They do not run SQL or instantiate a process when a facade action exists.[^user-facade]

There is no authorization policy layer. Isolation is "this row's `user_id` is the authenticated user", enforced inside repositories.

Side effects (mail, tokens, balance changes, broadcasts) live in processes. Records do not send mail or settle money.

# What belongs where

| Concern | Home |
|---------|------|
| Use case | `Core::<Context>::<Action> < ApplicationSolidProcess` |
| Domain value | `Core::<Context>::Entity` and small modules (`Kind`, `Status`) |
| Port | `Core::<Context>::Repository::Interface` |
| Adapter | `<Context>::Repository::Adapters::ActiveRecord` |
| HTTP | `API::V1::<Context>::*Controller` |

[Money and identity](/architecture/money-and-identity.md) is the persistence contract those adapters must keep. [Sessions](/identity/sessions.md) and the [HTTP surface](/delivery/http-surface.md) are the two edges a client actually touches.

[^registration]: `Core::User::Registration` is the canonical process: deps typed to interfaces, input normalized in the process, persistence only through the repository.
[^user-facade]: `User` exposes the use cases; controllers call the facade.
