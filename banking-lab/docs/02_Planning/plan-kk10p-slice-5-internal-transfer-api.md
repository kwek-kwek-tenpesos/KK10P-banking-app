# Slice 5 Plan: Internal Fake-Money Transfer API

- Status: Approved and implemented as a verified backend candidate on 2026-09-09; shared rollout, live transfer, Flutter Slice 6, and authenticated active ZAP remain separately gated.
- Parent roadmap: [KK10P prototype-to-Flutter roadmap](plan-kk10p-prototype-to-flutter-roadmap.md).
- Existing contracts: [customer authentication](../04_Architecture/customer-authentication-contract.md), [customer accounts](../04_Architecture/customer-accounts-contract.md), and [ledger/Development funding](../04_Architecture/ledger-development-funding-contract.md).
- Primary actors: Chris and Gio as separately authenticated customers with separate open PHP simulator accounts.

## 1. Request Understanding and Goal

Build the server-authoritative operation that moves fake PHP funds from the authenticated customer's account to another open KK10P simulator account. The transfer must commit exactly once, debit and credit atomically, preserve total customer value, prevent negative balances, enforce the approved Philippine-day limits, and return a safe receipt that Slice 6 can consume.

This is a backend-led slice. It deliberately does not expose a Transfer button or unfinished navigation in Flutter. Slice 6 will build the recipient, amount, review, submit, uncertainty, and receipt experience only after this API is implemented and verified. Slice 7 will add paginated Activity/history and transaction detail.

## 2. Scope

### In scope

- Internal fake-money transfer between two distinct, already-open PHP simulator accounts.
- Source account derived only from the authenticated, persisted, eligible customer session.
- Destination selected by the existing UUID simulator account reference.
- Canonical positive integer-string amount in centavos.
- Minimum PHP 0.01 and maximum PHP 50,000.00 per committed transfer.
- PHP 100,000.00 aggregate outgoing limit per source account per `Asia/Manila` calendar day.
- UUID idempotency, same-request replay, conflict detection, deterministic account locking, and atomic balance/posting writes.
- One `INTERNAL_TRANSFER` ledger transaction with exactly two customer postings: negative source and positive destination.
- A safe sender receipt containing references, amount, source balance after commit, server timestamp, completion status, and replay state.
- Exact API guards, stable error codes, no-store behavior, server-generated request correlation, restrained structured logs, operation timing, automated tests, a reviewed migration, and rollout documentation.

### Out of scope

- Flutter Transfer screens, Home activation, bottom navigation, Activity/history, receipt lookup, PDF/share, notifications, email, or push alerts.
- External banks, InstaPay integration, QR, bills, deposits, requests, scheduled/recurring transfers, beneficiaries, fees, reversals, refunds, disputes, holds, pending settlement, or multiple currencies.
- Searching customers by name, email, phone, user ID, or exposing recipient personal data.
- Multiple source accounts, account freeze/closure states, KYC/AML workflows, administrator approval, or a customer-support override.
- Direct balance edits, ledger-row mutation, migration seed transfers, or a Development-only shortcut that bypasses the transfer contract.
- PIN/biometric step-up. Restored-session app lock remains a separate security slice; the current valid bearer plus persisted session is the authorization boundary for Slice 5.
- Flutter-wide crash/error capture, client telemetry ingestion, an operational-error database, dashboards, alert routing, and retention policy. Those remain a dedicated observability slice after the transfer and Activity journeys establish the events worth monitoring.

## 3. Confirmed Product Policy

| Rule | Slice 5 decision |
| --- | --- |
| Currency | PHP only |
| Minimum | PHP 0.01 (`1` minor unit) |
| Per-transfer maximum | PHP 50,000.00 (`5,000,000` minor units) |
| Daily outgoing maximum | PHP 100,000.00 (`10,000,000` minor units) per source account |
| Daily boundary | Server-calculated `Asia/Manila` midnight-to-midnight, converted to a half-open UTC range |
| Counts toward daily limit | Only newly committed negative source postings for `INTERNAL_TRANSFER` |
| Does not count | Incoming transfers, Development funding, rejected requests, and idempotent replays |
| Self-transfer | Rejected |
| Recipient identifier | Existing UUID simulator account reference only |
| Settlement state | Immediately `COMPLETED` when the database transaction commits; no pending state in this slice |

The PHP 50,000 per-transfer value is compatible with the BSP InstaPay ceiling that informed the product decision. KK10P's PHP 100,000 aggregate daily ceiling is its own simulator rule, not a claim that BSP mandates one universal daily limit for every institution.

## 4. Architecture Decision

Reuse the Slice 4 journal rather than add a second transfer table:

- `LedgerTransactions` remains the immutable operation envelope and idempotency record.
- `LedgerPostings` remains the immutable movement detail.
- `CustomerAccounts.BalanceMinor` remains the transactionally maintained current-balance snapshot.
- `LedgerTransactions.BalanceAfterMinor` means the initiating/source customer's balance after a committed transfer.
- A transfer's two postings identify both customer accounts; the other posting is the counterparty for future Activity projection.
- No raw request, email, display name, token, or idempotency key is copied into a receipt payload or log.

This is sufficient for immediate internal settlement and later sender/recipient history. A recipient balance-after snapshot is not added because the planned receipt does not display it and reconstructing it is not required for Slice 7. If a future audited statement requires per-posting running balances, that must be a separate schema decision.

### Why the administrator portal is not needed now

The current two customers can open and fund their own accounts through already-authorized Development behavior. The transfer API derives ownership from authentication and needs no manual approval queue, user search, override, or dispute tooling. Pulling the React headquarters portal forward would add high-risk roles before the customer transfer invariant is stable. The admin track remains after customer transfer/history unless a later requirement introduces a genuinely admin-only operation.

## 5. Proposed API Contract

### `POST /api/v1/transfers/internal`

Transport and headers:

- HTTPS required; plain HTTP returns `400` and never redirects.
- Current eligible customer bearer session required.
- Exactly one canonical UUID `Idempotency-Key` header.
- `Content-Type: application/json`.
- No query parameters.
- Maximum body size 16 KiB, including streamed/chunked bodies.
- Responses under `/api/v1/transfers` use `Cache-Control: no-store`.
- Every response includes a server-generated `X-Request-ID`; client-supplied request IDs are not trusted in this slice.

Exact request shape:

```json
{
  "destinationAccountReference": "22222222-2222-2222-2222-222222222222",
  "amountMinor": "5000000"
}
```

Rules:

- Both fields are required and unknown fields are rejected.
- `destinationAccountReference` is one canonical non-empty UUID in `D` form.
- `amountMinor` is a canonical base-10 integer string with no sign, decimal, whitespace, exponent, or leading zero.
- Its parsed value must be between `1` and `5000000` inclusive and within signed 64-bit storage.
- Source account ID, owner, currency, date, status, and balance are never client-selectable.

First committed success: `201 Created`. Same customer, same key, and same canonical request: `200 OK` with the original persisted values and `replayed: true`.

```json
{
  "transactionId": "11111111-1111-1111-1111-111111111111",
  "sourceAccountReference": "33333333-3333-3333-3333-333333333333",
  "destinationAccountReference": "22222222-2222-2222-2222-222222222222",
  "currency": "PHP",
  "amountMinor": "5000000",
  "sourceBalanceAfterMinor": "5000000",
  "status": "COMPLETED",
  "createdAtUtc": "2026-09-09T00:00:00Z",
  "replayed": false
}
```

The receipt exposes no email, phone, display name, user ID, credential, or recipient balance. The UUIDs are the same simulator references already shown to their respective customers.

### Error contract

| Condition | Status | Stable code / behavior |
| --- | ---: | --- |
| Insecure transport, malformed UUID/key/JSON, unknown field, invalid amount | `400` | Problem Details; input-specific safe detail |
| Missing/invalid/revoked/expired/ineligible session | `401` | Existing auth behavior |
| Authentication/session dependency unavailable | `503` | Existing auth behavior |
| Source account is not open | `409` | `account_not_opened` |
| Destination reference has no open account | `404` | `recipient_not_found`; no customer data |
| Destination equals source | `409` | `self_transfer_not_allowed` |
| Same key is reused for another operation, destination, or amount | `409` | `idempotency_conflict` |
| Source funds are insufficient | `409` | `insufficient_funds` |
| Philippine-day outgoing cap would be exceeded | `409` | `outgoing_daily_limit_reached` |
| Unsupported media | `415` | Problem Details |
| Body exceeds 16 KiB | `413` | Problem Details |
| Route budget exceeded | `429` | `Retry-After` present |
| Expected transient database failure | `503` | Safe retry guidance using the same key |

An unavailable recipient response confirms only that the supplied random account reference cannot receive this transfer. Account ownership or personal fields are never returned. Current accounts have only an open/existing state—freeze, closure, and recipient eligibility states must not be invented in this slice.

Problem Details failures include the same safe request ID as a `traceId` extension so a tester can match the response to server diagnostics without exposing implementation details.

## 6. Idempotency and Request Fingerprint

Keep the existing unique `(InitiatedByUserId, IdempotencyKey)` index. This intentionally spans Development funding and internal transfer operations.

For a new transfer, compute a fixed 64-character SHA-256 fingerprint from a versioned, server-canonical representation containing:

```text
internal-transfer:v1 | source account UUID | destination account UUID | PHP | amountMinor
```

- Same user/key/fingerprint/operation returns the original receipt and does not re-run balance, daily-limit, or posting effects.
- Same user/key with a funding record or different transfer fingerprint returns `idempotency_conflict`.
- A rejected pre-commit validation does not append a transaction or consume the daily money allowance.
- Flutter Slice 6 must retain one key after timeout/connection uncertainty and use a new key only for a newly confirmed logical transfer.

## 7. Atomic Transaction and Locking Logic

All money checks and writes occur in one PostgreSQL transaction. A phone animation, disabled button, or client cache is never the concurrency control.

```text
AUTHENTICATE persisted eligible customer session
VALIDATE HTTPS, exact route/body/query/media/size, UUID key and canonical fields
READ the authenticated customer's source account reference
BEGIN PostgreSQL transaction
    LOCK source and requested destination account rows
        in ascending account-UUID order using SELECT ... FOR UPDATE
    IDENTIFY source by authenticated owner, never by request data
    LOOK UP transaction by authenticated user + idempotency key
    IF found:
        compare INTERNAL_TRANSFER + canonical fingerprint
        return original receipt or idempotency_conflict
    IF destination is absent: return recipient_not_found without a write
    IF destination equals source: return self_transfer_not_allowed
    CALCULATE Philippine business-day range from server TimeProvider
    SUM committed negative source postings for INTERNAL_TRANSFER in that range
    REJECT if amount exceeds per-transfer/daily policy
    REJECT if source balance is insufficient
    CHECKED subtract source balance and add destination balance
    APPEND one INTERNAL_TRANSFER envelope
    APPEND position 1 negative source posting
    APPEND position 2 equal positive destination posting
    SAVE balances + envelope + postings together
COMMIT
RETURN the persisted sender receipt with no-store
```

Deterministic UUID lock ordering prevents A→B and B→A requests from locking accounts in opposite order. Any two outgoing requests from one source share its row lock, so their balance and daily-limit decisions serialize. Any exception before commit rolls back both balance snapshots and all journal rows.

## 8. Data and Migration Plan

### Required model change

- Add constant `INTERNAL_TRANSFER` to `LedgerTransaction`.
- Widen `CK_LedgerTransactions_Operation` from equality with `DEVELOPMENT_FUNDING` to an explicit allow-list containing `DEVELOPMENT_FUNDING` and `INTERNAL_TRANSFER`.
- Reuse the current posting positions, currency, non-zero, exactly-one-account, relationship, and append-only constraints.
- Preserve the existing transaction, posting, account, identity, and session rows unchanged.
- Add no seed, backfill, transfer, balance update, user update, or direct data rewrite.

No new table or column is proposed. The existing posting-by-customer and transaction-time indexes support this educational two-customer workload; index expansion should be justified by measured history-query behavior in Slice 7 rather than guessed now.

### Migration safety gates

After implementation approval:

1. Generate one named EF migration from the reviewed model change.
2. Inspect generated C# and SQL; it may only replace the operation check constraint and update the model snapshot.
3. Prove upgrade behavior in a brand-new local database named exactly `banking_lab_transfer_test`.
4. Confirm existing funding rows still satisfy the widened check and Development funding still works.
5. Run the complete database-free and Flutter regression suites.
6. Stop/quiesce the shared API, capture counts/sums/migration marker, and take/verify a new pre-Slice-5 backup.
7. Ask for separate explicit approval before applying that exact migration to shared `banking_lab`.
8. After application, re-check identities, sessions, accounts, balances, transaction/posting counts, posting sum, constraints, indexes, and EF model drift before restarting.

The Down migration would narrow the check back to funding-only and will fail or become destructive after an internal transfer exists. Normal application rollback must retain the widened schema. Database rollback after live transfers requires a separate recovery decision and verified backup.

## 9. Security, Privacy, and Reliability Requirements

- The backend takes the source owner from `HttpContext`; Flutter cannot select or impersonate it.
- Existing bearer validation continues to require a live persisted session plus enabled, confirmed, unlocked customer.
- Destination lookup accepts only the opaque account UUID and returns no unrelated customer record.
- Checked integer arithmetic only; no decimal/floating-point money.
- One explicit route policy limits abusive bursts (proposed: 10 attempts/minute per trusted transport client IP, no queue) independently of the monetary cap.
- Expected transient storage failures return generic `503`; raw PostgreSQL/EF errors never reach the response.
- A small request-correlation middleware generates a fresh opaque request ID, sets `HttpContext.TraceIdentifier`, opens a logging scope, and returns the same value in `X-Request-ID`. It does not accept an arbitrary caller-provided ID as authoritative.
- Transfer completion, safe replay, policy rejection, throttling, transient storage failure, and unexpected failure are structured events with stable outcome/reason codes and elapsed milliseconds. Normal validation failures are not promoted into noisy exception logs.
- Structured logs may contain the request ID and committed transaction ID. They exclude bearer/refresh tokens, idempotency keys, request bodies, amounts, email, display name, user ID, and complete source/destination account references.
- The immutable ledger remains the financial audit record; operational logs are diagnostic metadata and never replace ledger transactions or postings.
- Every transfer-path response is non-cacheable, including guard, auth, throttle, success, and failure responses.
- The endpoint maps in every application environment because internal fake-money transfer is a core simulator feature; unlike Development funding, it is not a funding backdoor. The product must continue to disclose that all money is simulated.
- API cancellation or timeout never fabricates a failure/success conclusion. The client must retry an uncertain request with the same key.

## 10. State and User-Journey Boundary

Slice 5 ends with an API contract, not a customer-visible flow:

| Stage | Slice 5 result | Later owner |
| --- | --- | --- |
| Recipient entry | Contract accepts one account reference | Slice 6 Flutter |
| Amount entry | Contract accepts canonical centavos | Slice 6 Flutter formatting/validation |
| Review/confirmation | Not an API concern | Slice 6 Flutter |
| Transfer execution | Atomic endpoint in this slice | Slice 5 |
| Success receipt | API response in this slice | Slice 6 presentation; Slice 7 persisted lookup |
| Home balance refresh | No Flutter change in this slice | Slice 6 invalidates account state |
| Recipient refresh | Recipient sees new balance on their next existing account refresh | Slice 6/7 integration |
| Activity/history | Ledger already queryable but no public list/detail endpoint | Slice 7 |

No inactive Transfer navigation or mock receipt is added during Slice 5.

## 11. Planned Files

| Path | Planned responsibility |
| --- | --- |
| `banking-lab/backend/Banking.api/Features/Transfers/InternalTransferContracts.cs` | Policy constants, exact request, receipt, outcomes, and fingerprinting |
| `banking-lab/backend/Banking.api/Features/Transfers/InternalTransferRequestGuards.cs` | HTTPS/no-store, exact JSON, size/query/media/key, and rate-limit guards |
| `banking-lab/backend/Banking.api/Features/Transfers/InternalTransferService.cs` | Deterministic row locks, replay, limits, checked balances, journal append, commit |
| `banking-lab/backend/Banking.api/Features/Transfers/InternalTransferEndpoints.cs` | Route mapping and stable Problem Details responses |
| `banking-lab/backend/Banking.api/Features/Ledger/LedgerTransaction.cs` | Add the approved operation constant |
| `banking-lab/infrastructure/temporary/AppDbContext.cs` | Widen operation allow-list; preserve append-only balanced-pair validation |
| `banking-lab/backend/Banking.api/Program.cs` | Register correlation middleware, guards/service, and the transfer route |
| `banking-lab/backend/Banking.api/Observability/RequestCorrelationMiddleware.cs` | Generate one safe request ID, logging scope, response header, and Problem Details correlation value |
| `banking-lab/backend/Banking.api/Migrations/<generated>_AddInternalTransfers.cs` | Constraint-only reviewed migration; exact generated name recorded later |
| `banking-lab/backend/tests/Banking.IntegrationTests/InternalTransferEndpointTests.cs` | Database-free endpoint, auth, input, policy, replay, ownership, and errors |
| `banking-lab/backend/tests/Banking.IntegrationTests/PostgresInternalTransferTests.cs` | Fresh PostgreSQL upgrade, locks, conservation, concurrency, cap, and constraints |
| `banking-lab/docs/04_Architecture/internal-transfer-contract.md` | Canonical implemented contract, created during delivery after approval |
| `banking-lab/docs/03_Walkthroughs/walkthrough-kk10p-slice-5-internal-transfer-api.md` | Delivered outcome, concepts, flow, paths, commands, results, rollout, and QA |

No Flutter source file is planned for Slice 5.

## 12. Automated Verification Plan

### Database-free/API tests

- First success returns `201`; a same-key replay returns `200` and identical persisted receipt values.
- Same key with another amount, recipient, or Development funding operation returns `idempotency_conflict`.
- Source ownership always follows the authenticated user, even if malicious extra/source fields are submitted.
- Missing source, unknown recipient, self-transfer, insufficient funds, daily cap, and malformed/oversized/streamed input map to their documented safe responses.
- Insecure HTTP, redirects, query strings, unsupported media, missing/duplicate/malformed key, missing/forged/revoked session, and throttling fail closed with no-store.
- Amount parsing rejects zero, negatives, plus signs, decimals, exponents, whitespace, leading zeros, JSON numbers, overflow, and values over PHP 50,000.
- Manila midnight uses server time and the half-open boundary correctly.
- No failure path appends a ledger transaction/posting or changes a balance.
- Success and failure responses carry the same server-generated request ID in `X-Request-ID`; Problem Details also carries it as `traceId`.
- Transfer logs expose stable outcome and duration fields without tokens, idempotency keys, bodies, amounts, personal data, or complete account references.

### Fresh PostgreSQL tests

- Upgrade from the deployed Slice 4 schema preserves seeded users, sessions, accounts, funding rows, balances, and zero-sum reconciliation.
- One A→B transfer produces one envelope, two equal/opposite customer postings, exact balances, source balance-after receipt, and unchanged total customer value.
- Concurrent same-key requests commit one logical transfer and replay the same transaction.
- Concurrent distinct transfers from one source cannot overspend or exceed PHP 100,000 daily.
- Concurrent A→B and B→A requests complete without deadlock and preserve value.
- Incoming and Development funding postings do not consume outgoing allowance; replay does not consume it twice.
- A third transfer that would exceed the daily cap is rejected without partial writes.
- Existing Development funding continues to produce valid issuer/customer pairs after the operation constraint is widened.
- Database constraints and EF append-only/balanced-pair validation reject unsupported operations, negative balances, malformed pairs, and ledger mutation.
- `HasPendingModelChanges()` is false after the generated migration.

### Regression gates

- Complete .NET build and ordinary test suite.
- Guarded fresh `banking_lab_transfer_test` suite only; the fixture refuses non-loopback, wrong-name, custom-search-path, or already-migrated targets and never drops a database.
- Complete Flutter analysis and test suite even though no Flutter source changes are planned.
- Scoped format/diff/security review and secret scan before handoff.

## 13. OWASP ZAP Security Gates

ZAP complements the deterministic API, authorization, idempotency, limit, and concurrency tests; it does not replace them.

### Gate A — optional pre-Slice-5 baseline

- Run the existing guarded `run-zap-scan.ps1` in `-S` safe mode against its generated read-only definition, which permits only `GET /api/v1/system/info`. This establishes a passive/header baseline before transfer code changes without claiming authenticated or whole-API coverage.
- Retain its local-target allowlist, no-redirect probe, installed-image-only rule, one-use report directory, container hardening, and offline safety tests. It can reach the current local API because its synthetic definition excludes authentication and every state-changing route.
- This is useful evidence but does not block Slice 5 implementation. If only one ZAP run is scheduled, prefer Gate B.

### Gate B — Slice-5 exit gate

- After the transfer endpoint and automated tests are complete, run an authenticated OpenAPI API scan against a fresh disposable database containing purpose-built scanner accounts and funds.
- Begin with safe mode, validate route discovery and authentication, then run the approved active scan only against that isolated target.
- Confirm the OpenAPI document covers all currently exposed routes, including authentication, account, Development funding where enabled, and internal transfer; do not maintain a hand-written partial endpoint list.
- Preserve HTML, JSON, and Markdown reports outside source control unless a sanitized report is explicitly approved for documentation.
- Triage every High/Medium finding and document false positives with evidence. No unresolved High or Critical finding may pass the Slice 5 exit gate.

The image pull, scanner execution, active requests, and any disposable-database creation/destruction require their own explicit execution approval. The canonical scan design is maintained in [the ZAP plan](plan-owasp-zap-baseline-scan.md).

## 14. Shared Rollout and Manual Verification

Shared rollout remains a separate approval gate because the migration changes durable ledger rules. No live transfer is required to validate the migration itself.

After an approved rollout:

1. Verify the private HTTPS health path and unauthenticated transfer probe (`401`, no-store, no write).
2. Confirm both existing account balances and all four funding transactions/eight postings remain unchanged and reconciled.
3. Do not use direct SQL to create a transfer or alter either balance.
4. Prefer the first real Chris↔Gio transfer through the Slice 6 reviewed Flutter confirmation flow.
5. If an authenticated API-only live transfer is proposed before Slice 6, present its exact source, destination, amount, expected balances, and cleanup/reversal limitation for separate approval first.

## 15. Acceptance Criteria

- [x] Only an eligible authenticated customer with an open account can initiate a transfer.
- [x] The request cannot select or override its source account/owner.
- [x] Only another open PHP simulator account UUID can receive the transfer; no personal recipient data is exposed.
- [x] Amount is canonical integer centavos from PHP 0.01 through PHP 50,000.00.
- [x] Aggregate newly committed outgoing transfer value cannot exceed PHP 100,000 per source account per Philippine calendar day.
- [x] Incoming transfers, Development grants, rejected attempts, and replays do not consume that allowance.
- [x] One commit updates both balances and appends one balanced two-customer posting pair; any failure updates nothing.
- [x] Customer balances never become negative and total customer value is conserved by a transfer.
- [x] Same-key retries are safe under timeout and concurrency; conflicting reuse is rejected.
- [x] Cross-transfers lock accounts deterministically and do not deadlock.
- [x] Success and all documented failures are no-store, safe, stable, and covered by tests.
- [x] Every transfer response has a server-generated request ID, Problem Details exposes the same safe `traceId`, and structured transfer logs record outcome and duration without sensitive values.
- [ ] Gate A passed before implementation; authenticated safe-then-active Gate B remains separately approved execution against a disposable target.
- [x] The constraint-only migration preserves existing data and is proven on a fresh disposable PostgreSQL database before shared approval is requested.
- [x] Existing funding, authentication, account, and Flutter behavior remains green.
- [x] No Transfer UI, Activity UI, admin behavior, app lock, or public tunnel change is introduced.
- [x] Delivery docs include outcome, at least three concepts, sequential logic, important paths, safe customization points, exact PowerShell commands, real verification results, migration/backup evidence, limitations, and next steps.

## 16. Approval Gates and Recommended Sequence

Approval of this plan authorizes implementation source, database-free tests, migration generation/review, and a fresh disposable `banking_lab_transfer_test` proof. It does **not** authorize applying the migration to shared `banking_lab`, executing a live customer transfer, Git add/commit/push, Flutter Slice 6, Activity Slice 7, administrator work, app-lock work, or tunnel replacement.

Recommended sequence after explicit approval:

1. Optionally capture the non-blocking pre-change ZAP safe-mode baseline against a disposable target after separate scan approval.
2. Implement request correlation, contracts/guards/service/endpoint, safe structured events, and database-free tests.
3. Widen the EF operation allow-list and generate one migration.
4. Inspect migration code/SQL before execution.
5. Prove upgrade, atomicity, limits, idempotency, and concurrency in the exact fresh disposable database.
6. Run all backend/Flutter regression gates and complete a scoped security/diff review.
7. Run the approved authenticated safe-then-active ZAP API scan against its disposable target and triage findings.
8. Present evidence and request separate shared-migration approval.
9. After shared rollout and reconciliation, plan Slice 6 Flutter Transfer journey.
