# Client Platform Adoption Decision

- Status: Approved by Chris on 2026-09-07; corrected frontend experience details remain governed by the linked roadmap's Revision A gate.
- Decision date: 2026-09-07.
- Scope: How `D:\OtherProjects\Banking-UI-UX-Prototype` informs Banking Lab.
- Related roadmap: [prototype-to-Flutter roadmap](../02_Planning/plan-kk10p-prototype-to-flutter-roadmap.md).
- Design audit: [prototype adoption audit](../05_Design/kk10p-prototype-adoption-audit.md).

## Context

Banking Lab already has a functional Flutter customer app connected to an ASP.NET Core API and PostgreSQL. The separate Kotlin/Jetpack Compose repository is a disconnected UI prototype with extensive local mock state. It demonstrates useful visual layouts but does not implement Banking Lab's authentication, session, account ownership or API contracts.

The team needs a maintainable route from the prototype design to the existing product without running two customer clients or importing simulated behavior as trusted banking logic.

## Decision

Rebuild selected, approved prototype presentation patterns in the existing Flutter client. Do not convert the Kotlin application line by line, embed it, merge its Gradle project or copy its state/data/dependency architecture.

The existing system remains one modular monolith:

```text
Flutter customer client
        |
        | HTTPS JSON API
        v
ASP.NET Core application/API
        |
        v
PostgreSQL authoritative data
```

- Flutter owns presentation, accessibility, local transient UI state and secure refresh-token storage.
- ASP.NET Core owns authentication, authorization, validation, idempotency and domain workflows.
- PostgreSQL owns durable accounts, future ledger postings, transfers and audit-safe state.
- A future administrator web surface will use backend-enforced roles against the same application boundary; it will not be hidden inside the customer client.

## Why This Is the Simplest Reliable Option

- It preserves the already verified auth/session/account implementation.
- It avoids maintaining Kotlin and Flutter versions of every screen.
- It prevents hard-coded mock data from becoming an accidental source of truth.
- It adds no Firebase, Room, Retrofit, Moshi or Android-only dependency to Banking Lab.
- It keeps future transfer and funding logic authoritative and testable on the server.
- It allows small, reversible visual slices before high-risk financial-domain work.

## Rejected Alternatives

### Replace Flutter with the Kotlin prototype

Rejected because it would discard working integration, require a new API/session layer, narrow platform portability and translate 35,000+ lines of mostly mock UI before delivering real behavior.

### Run both customer clients

Rejected because a small learning project would duplicate UI, security, test and release work and allow behavior to drift.

### Copy prototype models and local state into Flutter

Rejected because balances, transfers, security controls and KYC state must not be client-authoritative.

### Add prototype Firebase/Room/network dependencies

Rejected because those dependencies are unused in the prototype source and duplicate the current architecture without solving a Banking Lab requirement.

## Consequences

- Visual components are recreated idiomatically in Dart rather than mechanically translated.
- Screens may resemble the prototype while containing less content and fewer actions.
- Unsupported prototype screens stay out of customer navigation.
- Funding, transfer and activity work requires backend contracts and, where needed, separately approved migrations.
- Android phone behavior is the primary manual target; 768-width layout remains a resilience check rather than a full desktop product.

## Revisit Conditions

Reconsider this decision only if Flutter is formally abandoned, a second native Android client becomes an explicit product requirement, or measured platform constraints prove the existing Flutter client cannot meet a required capability.
