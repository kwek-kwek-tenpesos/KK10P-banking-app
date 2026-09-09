# KK10P Prototype-to-Flutter Master Roadmap

- Status: Revision A, Slice 1 and Slice 2 are complete and physically approved. Slice 3 Home/account planning is next; no Slice 3 implementation is approved yet.
- Prepared: 2026-09-07.
- Goal: Translate the approved parts of the AI Studio Kotlin prototype into a clean, truthful and maintainable Flutter customer experience, then add the smallest backend-led fake-money features needed for Chris and Gio to transact.
- Design source: [prototype adoption audit](../05_Design/kk10p-prototype-adoption-audit.md).
- Architecture decision: [client platform adoption decision](../04_Architecture/client-platform-adoption-decision.md).
- Current contracts: [authentication](../04_Architecture/customer-authentication-contract.md) and [accounts](../04_Architecture/customer-accounts-contract.md).

## 1. Desired Outcome

Chris and Gio can use one polished Android customer app to:

1. see one truthful technical/simulator introduction on first install;
2. choose and retain an accessible Light, Dark or System appearance;
3. register and verify a simulator identity;
4. sign in and restore/revoke sessions safely;
5. open and view one PHP simulator account;
6. obtain auditable Development-only fake funds through an explicitly approved mechanism;
7. transfer fake PHP funds to another registered simulator account;
8. review an accurate transaction history and transfer receipt;
9. sign out without stale customer data remaining visible.

The app should look like the supplied prototype after its mock/test scaffolding, unsupported claims, duplicate modules and hybrid visual inconsistencies are removed.

## 2. Actors and Boundaries

| Actor | In this roadmap | Not in this roadmap |
| --- | --- | --- |
| First-install customer | Truthful introduction, appearance choice, Sign In or Create Account | Unsupported marketing/security claims or evaluator bypass |
| Signed-out customer | Startup, login, registration, resend and verification; Create Account visibility based on non-authenticating local attachment state | PIN, biometric, phone/account-ID login, password reset |
| Signed-in customer | Home, one account, funding if separately approved, internal transfer, activity, basic profile/about/logout | Real payments, external bank rails, KYC, disputes, device security center |
| Developer/evaluator | Tests, previews and explicit Development-only simulator tools | Customer-visible batch/state switchers or hard-coded credentials |
| Administrator | Future architecture only | No current portal, permissions or customer-management UI |
| Backend | Identity, sessions, account ownership, balances, ledger, transfers and idempotency | Trusting client totals or local mock state |

## 3. Delivery Strategy

This master roadmap is implemented slice by slice. Before any non-trivial slice begins, its affected files, exact API/schema changes and acceptance tests are refined in a feature-specific plan and explicitly approved. After approval, active execution moves to `docs/01_Tracking/task.md`; this roadmap is not repeatedly reinterpreted during coding.

Visual work comes first because it is reversible and can be tested against existing behavior. Ledger/funding/transfers come later because they change authoritative data and require separate migration approval.

### Frontend-first answer

Focusing on the frontend foundation before the new backend features is a sound workflow here. Existing authentication and account APIs already provide real behavior for the first frontend slices. For features that do not yet have APIs—funding, Transfer and Activity—the frontend may define design specs, view-model shapes, golden fixtures and debug-only previews, but it must not expose release navigation or pretend mock values are real. Before those features are wired, their server contracts are designed and approved; the backend is then implemented before the customer-facing action is enabled.

This gives two deliberate phases:

```text
Frontend phase now:
  material proof + light/dark system
  first-install introduction and local experience state
  current authentication/verification/diagnostics
  current Home and one-account states
  PIN/Activity visual references documented or debug-previewed only

Backend-led phase next:
  ledger + Development funding
  internal transfer API
  transfer UI activation
  activity/history API and UI activation
  final navigation/Home integration
```

"Professional-grade" means explicit security, privacy, reliability and deployment checks; no software should be described as bulletproof. Public deployment remains blocked until the relevant security review, production configuration, verified app links, secret handling, observability, backup/restore and release-signing gates are completed.

```text
Audit and approve direction
  -> Slice 1 light/dark visual system proof
  -> Slice 2 first-install experience and existing auth surfaces
  -> Slice 3 current account/Home surfaces
  -> Slice 4 ledger and simulator funding design
  -> Slice 5 internal transfer API
  -> Slice 6 Flutter transfer journey
  -> Slice 7 activity/history and receipt
  -> Slice 8 navigation and clean Home integration
  -> Slice 9 hardening, device acceptance and handoff
  -> Future: administrator web portal
```

## 4. Slice 0 — Audit and Scope Freeze

### Outcome

Agree on one visual system, one platform and a truthful MVP feature set before changing code.

### Completed planning evidence

- Read the external master record and Kotlin source read-only.
- Compared its claimed behavior with actual Banking Lab routes and endpoints.
- Inspected Login, Home and Activity screenshots at source resolution.
- Identified the prototype as a disconnected local-state mock.
- Replaced the wrong desktop `temp.txt` with the corrected Banking Lab workspace note.
- Recorded the architecture choice and feature triage.

### Approval criteria

- [x] Chris accepts Flutter selective reconstruction rather than Kotlin replacement.
- [x] Chris accepts Kotlin as the principal layout/design reference while Flutter and ASP.NET remain authoritative implementation platforms.
- [x] Chris accepts a separate future administrator surface.
- [x] Chris confirms Revision A: first-install introduction, dark mode now, attached-account visibility semantics and frontend-first sequencing.

## 5. Slice 1 — Flutter Light/Dark Material System Proof

### Scope

Build the smallest reusable layer needed by real existing screens:

- centralized Light and Dark material, text, semantic, spacing, radius, depth and motion tokens;
- raised, inset, flat and solid-blue surface roles;
- native semantic button, icon button, input surface and major panel wrappers;
- the existing Material icon family; the prototype's JPEG bank/vault logo remains a replaceable candidate pending crop/compression and provenance review;
- one isolated component showcase reachable from developer diagnostics and covered by tests.

Do not create transfer/history/admin widgets yet.

### Pseudocode

```text
DEFINE separate light and dark material palettes
FOR each palette and reusable surface role:
    draw only its approved face and paired depth
    preserve native semantics and hit testing
    show explicit focus, validation and disabled indicators
WHEN pressed:
    transition promptly from raised to inset
WHEN cancelled:
    restore without firing the action
```

### Acceptance criteria

- [x] No ordinary surface uses an unapproved white card, orange CTA or screen-local shadow.
- [x] Raised controls use one top-left highlight/lower-right contact-shadow pair and a restrained hairline edge where needed for physical separation.
- [x] Editable fields retain focus/error states independent of decorative shadows.
- [x] Dark mode is independently tuned rather than mechanically inverted.
- [x] Native semantics, cancellation, rapid interaction and minimum 48-pixel targets are tested.
- [x] Automated coverage exercises both palettes plus resting, pressed, focused and disabled control states.
- [x] Chris physically approved the final Light/Dark material, container boundaries and pressed depth after hot-reload calibration on the authorized phone.

Light/Dark/System selection and persistence, plus screen-level loading/error/empty/offline composition, move to Slice 2 where they have real auth/startup consumers.

## 6. Slice 2 — First-Install Experience and Existing Authentication Surfaces

### Scope

Add the first-install experience state, then recompose Startup, Login, Registration, Email Verification and Diagnostics using Slice 1 components while preserving every current controller call and route.

### Product rules

- Startup reads session state, introduction-completion state and the non-sensitive known-account marker without an artificial delay.
- On first install, show one concise introduction with only verified information: fake-money simulator, HTTPS-required credential traffic, platform secure refresh-token storage, email verification, revocable sessions and the non-bank limitation.
- The introduction offers Sign In and Create Account, records completion only when a path is chosen, and remains available later through About.
- Later launches skip the introduction and restore a valid session or open Login.
- Login accepts email and password only.
- Resend Verification remains accessible but secondary.
- Set `known account attached` after successful login. Preserve it through session expiry/restore failure. Clear it only after explicit full Sign Out/removal from this device.
- Hide Create Account while a known account is attached; show it on first install and after explicit full logout.
- Registration remains email, password and optional display name.
- Verification remains the current one-use email-link confirmation.
- Diagnostics remains visually separate from banking actions.
- Provide an accessible Light/Dark/System chooser without crowding Login; the later More/About surface becomes its permanent signed-in home.
- No evaluator fast-track, canned credentials, UI-state chips, PIN, biometric or password-reset action appears.

The introduction-completed and known-account values are local experience hints only. They do not identify a customer, authorize a route, restore a session or suppress server-side authentication.

### Acceptance criteria

- [x] All existing auth success, validation, rate-limit, lockout, insecure-origin, offline and retry behavior remains unchanged.
- [x] No unsupported authentication method or security claim appears.
- [x] First install shows the introduction once; subsequent launches skip it; reinstall/cleared app data behaves as a first install.
- [x] A known attached account hides Create Account after login/session expiry, while explicit full logout shows it again.
- [x] Corrupt/missing experience flags fail safely to a usable signed-out route and never bypass authentication.
- [x] The introduction and About copy are sourced from verified repository behavior and remain accurate in both themes.
- [x] Password visibility semantics and secure-storage/session ordering tests still pass.
- [x] Layout passes at 320/360/412/768 widths and 200% text with keyboard-safe scrolling.
- [x] Physical Login/Registration/Verification comparison is accepted before moving on.

## 7. Slice 3 — Current Account and Clean Home Foundation

### Scope

Recompose the existing authenticated Home and all one-account states without inventing funds, transactions or destinations.

### Home before later features

```text
Greeting
Simulator disclosure
One account hero
  unopened -> Open account
  opening/loading -> progress
  loaded -> PHP 0.00 + simulator reference + Refresh
  error -> message + Retry
Sign out
Diagnostics/about entry if retained
```

### Acceptance criteria

- [ ] Home contains only API-backed data and working actions.
- [ ] Unopened, opening, loading, loaded, uncertain, error and retry states remain distinct.
- [ ] Account reference wraps safely and is never presented as a real account/routing number.
- [ ] No fake currency, growth, card, alert, transfer or activity data appears.
- [ ] Old-session/account responses cannot reappear after logout or customer change.
- [ ] Home passes TalkBack reading-order review on the authorized phone.

## 8. Slice 4 — Ledger and Development Funding Design

### Why it is required

The current database enforces a zero-only account. A transfer UI cannot be truthful or testable until funds and transaction authority exist. Editing a balance directly or using client mock data is not acceptable.

### Recommended funding option

Add a bounded, auditable, idempotent simulator-funding operation enabled only in the Development environment. It creates a ledger credit and corresponding history item rather than mutating a displayed total without evidence. The amount, per-customer limit and reset policy must be approved in the slice plan.

### Backend design work

- define immutable ledger entries/postings and derived or transactionally maintained balance;
- choose concurrency control and invariant checks;
- define integer minor-unit money handling for PHP only;
- define idempotency keys and replay responses;
- define an append-only audit trail without secrets or unnecessary personal data;
- design additive migrations and backup/rollback verification;
- disable the funding endpoint outside Development;
- retain ownership from the authenticated server session, never request-selected user IDs.

### Required approval gate

No schema change, migration generation/application or shared-database write occurs until the feature-specific plan and migration safety review are explicitly approved.

### Acceptance criteria

- [ ] Credits are ledger-backed, auditable, integer-based and server-authoritative.
- [ ] Repeated idempotency keys do not issue funds twice.
- [ ] Concurrent requests cannot violate balance/ledger invariants.
- [ ] The endpoint is unavailable outside Development.
- [ ] Disposable PostgreSQL tests pass before any separately approved shared rollout.

## 9. Slice 5 — Internal Fake-Money Transfer API

### MVP contract direction

- Source is the authenticated customer's open account.
- Destination is another open simulator account identified by public simulator account reference, not arbitrary user ID.
- Currency is PHP only.
- Amount is a positive integer number of centavos within approved bounds.
- Each request carries a client-generated idempotency key.
- Server validates ownership, destination, self-transfer policy, sufficient funds and account status.
- One database transaction records the transfer, debit posting and credit posting.
- Response returns an opaque transfer reference, status, amount, parties safe for display and timestamps.
- Logs never contain credentials or unnecessary full identifiers.

### Pseudocode

```text
AUTHENTICATE customer and persisted session
VALIDATE HTTPS, body size, exact JSON shape and idempotency key
LOAD source from authenticated owner
LOAD destination by simulator reference
BEGIN database transaction
    lock or version affected accounts in deterministic order
    IF idempotency record exists:
        return its original safe response
    VALIDATE positive PHP amount and sufficient source funds
    create transfer
    create balanced debit and credit postings
    update or derive balances under the chosen invariant
    persist idempotency result
COMMIT
RETURN no-store response
```

### Acceptance criteria

- [ ] Authorization never trusts a client-selected source owner.
- [ ] Transfer postings balance to zero and balances cannot become negative.
- [ ] Duplicate, concurrent and timeout-retry requests are safe.
- [ ] Unknown destination handling does not expose unrelated customer data.
- [ ] Integration tests cover success, insufficient funds, self/unknown destination, duplicate key, malformed body, auth/session failure and concurrency.

## 10. Slice 6 — Flutter Internal Transfer Journey

### Screens

```text
Recipient reference
  -> exact PHP amount
  -> review
  -> submit/processing
  -> success receipt or recoverable/definitive failure
```

### UI rules

- Use one primary action per step.
- Do not show unsupported rail, fee, speed, bank or biometric selectors.
- Preserve draft values when a recoverable error occurs.
- Disable duplicate submission while preserving Back before submission.
- Use the server result as the receipt source of truth.
- Explain fake-money/simulator status without overwhelming every step.

### Acceptance criteria

- [x] No transfer action is exposed until the backend contract is available.
- [x] Amount parsing uses integer minor units without floating point.
- [x] Duplicate taps send at most one logical transfer through idempotency.
- [x] An unresolved request retains its exact key and payload across route disposal or app restart so uncertainty is reconciled safely.
- [x] Success, insufficient funds, unknown recipient, offline, timeout uncertainty and server failure are distinguishable.
- [x] A successful transfer refreshes account state; Activity invalidation is connected when Slice 7 adds its provider.
- [ ] The journey is usable at 320 pixels and 200% text with TalkBack.

## 11. Slice 7 — Activity, History and Receipt

### Backend direction

- authenticated account-scoped transaction history;
- stable cursor pagination;
- server-owned direction/status values;
- optional compact direction/status filters;
- deterministic ordering by occurred-at time plus stable ID;
- transaction/transfer detail with only safe counterparty display data.

### Flutter direction

- date-grouped activity list;
- compact search/filter entry rather than three permanent filter rows;
- loading, empty, offline, error and pagination states;
- transaction detail and share-free in-app receipt first;
- bottom-safe padding so navigation never obscures rows.

### Acceptance criteria

- [ ] The list contains only the authenticated customer's account activity.
- [ ] Pagination has no missing/duplicate rows under stable data.
- [ ] Direction, amount and status are readable without color alone.
- [ ] Developer state selectors are absent from release UI.
- [ ] Empty/offline/error states provide truthful recovery actions.
- [ ] Receipt data matches the transfer response and persisted ledger.

## 12. Slice 8 — Navigation and Final Clean Home

### Scope

Introduce the customer navigation only when every exposed destination works.

Recommended MVP destinations:

```text
Home | Account | Transfer | Activity | More
```

If `Account` remains fully represented on Home, omit that duplicate destination until it gains distinct value. The center Transfer action is solid blue, not orange. Bottom-bar height plus system inset is reserved in each scrollable body's padding.

### Final Home

- greeting and optional basic profile entry;
- simulator disclosure;
- one account hero with mask, Refresh and one Transfer action;
- up to three recent ledger items plus View Activity;
- no static fake alert, savings, scheduled payment, cards or duplicate action row;
- only one contextual warning when backed by real server state.

### Acceptance criteria

- [ ] Every navigation destination loads working data and actions.
- [ ] No duplicate Transfer affordance competes in the same viewport.
- [ ] Home's first viewport remains clear at 360 pixels and 200% text.
- [ ] Bottom navigation never covers content, keyboard actions or error recovery.
- [ ] Back behavior, deep-link verification and session redirects remain correct.
- [ ] Navigation selection is announced correctly by TalkBack.

## 13. Slice 9 — Hardening and Handoff

### Automated gates

- Dart formatting and Flutter static analysis.
- Focused component, controller, repository and screen tests.
- Complete low-memory Flutter suite with single-worker execution.
- .NET formatting/build/unit/integration checks appropriate to changed slices.
- Disposable PostgreSQL migration and concurrency tests for data slices.
- API contract/OpenAPI alignment checks.
- APK build using runtime-only private HTTPS configuration.

### Manual gates

- Physical Android walkthrough for Chris and Gio accounts.
- 320/360/412 logical widths and 768 resilience layout.
- Normal and 200% text, keyboard open, portrait and practical landscape.
- TalkBack order and action announcements.
- Press, cancel, rapid-tap and slow/offline behavior.
- Session restore, logout and user-switch stale-data checks.
- Funding, transfer and history reconciliation across both customers.

### Documentation gates

- Update the nearest canonical design/API/data documents.
- Add one concise top changelog entry per completed behavior delivery.
- Create a delivery walkthrough with exact commands and truthful results.
- Archive each completed slice from the active task into its own dated file.
- Record unresolved public-release security boundaries.

## 14. Future Administrator Track

The administrator portal begins only after the customer MVP ledger/transfer/history is stable.

Recommended shape: a small protected web portal using the same ASP.NET Core application boundary and PostgreSQL data, with explicit roles and audit logging. Initial candidate operations are simulator-user lookup, account status review, controlled funding/reversal and manual identity-review notes. Exact operations, staff provisioning, multi-factor authentication, audit retention and privacy constraints require a dedicated architecture/security plan.

Do not implement administrator credentials, role shortcuts or hidden admin routes in the customer Flutter app.

## 15. Explicitly Deferred Tracks

- Password recovery, PIN, biometrics, passkeys and device integrity.
- Multiple accounts, cards, wallets and currencies.
- External-bank transfers, ACH/FedNow/wire, bill pay, deposit and QR flows.
- Beneficiaries, schedules, limits and cooldowns.
- Savings, goals, budgeting and round-ups.
- Push notifications, security center, devices and login history.
- Statements, exports, sharing and barcodes.
- Support tickets, disputes and attachments.
- Localization and full desktop/tablet navigation.
- Bluetooth demonstration and AI-guard concepts.

Each deferred track requires its own acceptance criteria and must not appear as a dead control.

## 16. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Prototype mock behavior is mistaken for implemented banking logic | Use current contracts and backend state as the only behavioral authority |
| Visual redesign becomes another endless token-tuning cycle | Approve one component proof on the physical phone before screen rollout |
| Neumorphism reduces clarity | Keep explicit focus/error/status indicators and test at 200% text/TalkBack |
| Home becomes crowded again | Enforce the documented Home order and three-item/action limits |
| Transfer retries duplicate money | Server idempotency plus atomic ledger transaction |
| Zero-only account blocks meaningful testing | Approve ledger-backed Development funding before transfer UI |
| Migrations affect shared data | Disposable DB first, backup, explicit approval, additive migration and post-check |
| New dependencies inflate a low-memory project | Reuse current stack; require justification for every new package |
| Admin scope delays customer MVP | Keep it a separate post-MVP track |

## 17. Master Acceptance Criteria

- [ ] The Kotlin prototype remains read-only and Flutter remains the only customer client.
- [ ] All shipped controls map to working API or local presentation behavior.
- [ ] The accepted single-material blue design is centralized and consistent in Light and Dark modes.
- [ ] The truthful introduction appears only on first install and remains accessible later from About.
- [ ] Create Account visibility follows the documented non-authenticating attachment marker without affecting authorization.
- [ ] Auth/session/account regressions remain green through every visual slice.
- [ ] Home is clean, truthful and free from bottom-navigation overlap.
- [ ] Fake funds, transfers and history are ledger-backed and reconcile across Chris and Gio.
- [ ] No real payments, external rails or misleading security/financial claims appear.
- [ ] Automated and physical-device evidence is recorded without fabricating passes.
- [ ] No migration, shared-data change, Git write or public deployment occurs without its required approval.

## 18. Approval Gate and Recommended First Action

The Flutter/ASP.NET platform decision and use of Kotlin as the main design/layout reference are approved. Revision A is planning only; no Flutter, backend, database or prototype code has been changed by its creation.

After Chris confirms Revision A, the recommended first implementation is Slice 1 as a deliberately small dual-theme component proof: one raised button, one pressed state, one inset field and one major surface rendered in Light and Dark modes on the authorized phone. Once that material proof is visually accepted, Slice 2 can add the first-install experience and apply the system to existing authentication screens without repeating broad redesign cycles.
