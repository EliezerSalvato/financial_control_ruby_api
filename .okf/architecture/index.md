# Architecture

* [Hexagonal boundary](hexagonal-boundary.md) - Money and identity change only inside Core processes; HTTP and Active Record stay at the edges.
* [Money and identity](money-and-identity.md) - Primary keys are UUIDv7, amounts are numeric(15,2), and names are unique per user ignoring case.
