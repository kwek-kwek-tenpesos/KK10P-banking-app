# Slice 4 Plan: Ledger and Development Funding Foundation

- Status: Approved by Chris on 2026-09-08 for implementation and automated verification against database-free/fresh disposable targets only. Shared-database migration and simulator credit remain separately gated.
- Parent roadmap: [KK10P prototype-to-Flutter roadmap](plan-kk10p-prototype-to-flutter-roadmap.md).
- Current contracts: [customer accounts](../04_Architecture/customer-accounts-contract.md) and [customer authentication](../04_Architecture/customer-authentication-contract.md).
- Actors: Chris and Gio as separate authenticated simulator customers using the shared Development API.

## 1. Request Understanding

Create the smallest trustworthy money foundation that lets Chris and Gio add bounded fake PHP funds to their own simulator accounts before internal transfers are built. Every issued centavo must be backed by an immutable journal transaction, survive retries without duplicate credit, respect concurrent requests, and remain unavailable outside Development.

This slice includes the backend ledger/funding implementation and one deliberately small authenticated Development-only trigger in API Diagnostics. It does not build Transfer or Activity yet.

## 2. Business Goal

Chris and Gio need reproducible non-zero balances for later two-customer transfer testing. Direct PostgreSQL balance edits, migration seeds, or Flutter mock balances would bypass authorization, idempotency, history, and audit evidence. Slice 4 establishes those foundations once so later transfers and receipts use the same server-authoritative journal.

## 3. Confirmed Boundaries

### In scope

- PHP integer minor units only; no floating-point money.
- One authenticated customer funds only their own already-open simulator account.
- Fixed Development grant: `PHP 50,000.00` (`5,000,000` minor units).
- Daily Development funding cap: `PHP 100,000.00` (`10,000,000` minor units) per account.
- At most two successful fixed grants per account per Philippine calendar day.
- A caller-generated UUID idempotency key retained across uncertain retries.
- One journal transaction with balanced issuer/customer postings per successful grant.
- Transactionally maintained `CustomerAccounts.BalanceMinor` with a non-negative database constraint.
- A minimal authenticated funding action in API Diagnostics, visible only when the API reports `Development`.
- Database-free contract tests and opt-in tests against a fresh disposable local PostgreSQL database.
- A separately approved backup, migration, and shared Development rollout after disposable verification.

### Out of scope

- Transfers, recipients, Activity/history UI, receipts, reversals, refunds, interest, cards, multiple currencies, or external payment rails.
- Arbitrary grant amounts, selecting another user/account, batch funding, or an administrator portal.
- Manually resetting a daily allowance. The funding window resets naturally at midnight in `Asia/Manila`; a future protected administrator/reversal design may add exceptional corrections after the ledger is stable.
- Direct SQL balance editing or automatic funding during registration/account opening.
- Production funding, production feature flags, or relying on Flutter visibility as authorization.
- Biometric/PIN app lock; this remains a separate authentication/security slice.

## 4. Recommended Policy Decisions

Approval of this plan approves these policy values for Slice 4:

| Decision | Recommendation | Reason |
| --- | --- | --- |
| Grant size | Fixed PHP 50,000 | Matches the proposed future per-transfer ceiling without accepting arbitrary money input |
| Daily funding cap | PHP 100,000 per account | Allows two full test grants per Philippine calendar day while bounding issuance |
| Daily boundary | `Asia/Manila`, 00:00 inclusive to the next 00:00 exclusive | Uses a stable server-side Philippine business day rather than a phone clock |
| Reset policy | Automatic next Philippine calendar day; no manual reset endpoint | Avoids reversal/accounting and administrator scope before transfers exist |
| Recipient | Authenticated customer's own account only | Preserves ownership and needs no admin role |
| User trigger | Development card in API Diagnostics | Usable by both testers without exposing a fake banking action on Home |
| Non-Development behavior | Route is not mapped; return 404 | Makes production exposure fail closed |

### Separate future transfer policy

The Development grant is simulator issuance, not a customer transfer, and does not consume the outgoing-transfer allowance. Slice 5 will use the following approved contract direction:

- maximum one internal transfer: `PHP 50,000.00` (`5,000,000` minor units);
- maximum aggregate outgoing transfers from one source account per `Asia/Manila` calendar day: `PHP 100,000.00` (`10,000,000` minor units);
- incoming transfers and Development funding do not count toward that outgoing limit;
- duplicate idempotent replays do not consume the limit again;
- the server's committed transaction timestamps and ledger postings, never the phone clock, determine the daily total.

These are KK10P simulator product rules, not a claim that every real bank uses the same limits. The BSP's [InstaPay FAQ](https://www.bsp.gov.ph/PaymentAndSettlement/FAQ_Instapay.pdf) describes a PHP 50,000 maximum per InstaPay transaction while directing customers to their institution for any aggregate daily limit; it does not establish a universal PHP 100,000 daily ceiling. KK10P deliberately adopts PHP 100,000 as its own clear daily rule.

## 5. Architecture Decision

- Current stage: private educational simulator with two customer testers.
- Recommended architecture level: keep the existing ASP.NET Core monolith, PostgreSQL database, Flutter client, and Tailscale Serve boundary.
- Build now: a small general journal envelope/posting model, one fixed self-funding operation, and a diagnostics trigger.
- Keep manual: migration approval, backup, shared-schema rollout, and final Chris/Gio funding verification.
- Do not build yet: an administrator portal, message broker, microservice, event-sourcing platform, generalized payments engine, or ledger reporting warehouse.

### Alternatives considered

1. **Directly edit `BalanceMinor`** — rejected because it creates no history, authorization, idempotency, or reconciliation evidence.
2. **Seed every account during migration/opening** — rejected because it silently changes existing behavior and cannot represent an intentional auditable funding event.
3. **Build the administrator portal first** — deferred because self-funding in Development solves the immediate two-tester need with a much smaller security surface.
4. **Store only a single funding-history row** — rejected because Slice 5 needs shared transaction/posting primitives for balanced transfers.

### Upgrade path

Slice 5 reuses the journal transaction and customer postings for one atomic source debit/destination credit. Slice 6 consumes that API in Flutter. Activity and receipts later read the same immutable journal. A separately secured administrator portal may eventually issue or reverse simulator funds using new transaction types, never by editing old postings.

## 6. Proposed API Contract

### `POST /api/v1/development/funding/me`

Purpose: issue one fixed PHP 50,000 simulator grant to the current authenticated customer's open account.

Request:

- HTTPS only through the existing trusted loopback/Tailscale boundary.
- Valid bearer session for a confirmed, enabled, unlocked customer.
- Header `Idempotency-Key` containing one canonical UUID.
- `Content-Type: application/json`.
- Exact empty object body `{}` and no query parameters.
- Maximum request body 16 KiB, including streamed input enforcement.

Success response fields use integer strings:

```json
{
  "transactionId": "11111111-1111-1111-1111-111111111111",
  "accountId": "22222222-2222-2222-2222-222222222222",
  "currency": "PHP",
  "creditedAmountMinor": "5000000",
  "balanceAfterMinor": "5000000",
  "createdAtUtc": "2026-09-08T00:00:00Z",
  "replayed": false
}
```

- First committed request: `201 Created`, `replayed: false`.
- Same customer and same key: `200 OK`, the original persisted receipt values, `replayed: true`, and no new posting/balance change.
- Missing/malformed key or body/query violation: `400` Problem Details.
- Missing account: `409` with stable `code: account_not_opened`.
- Reused key for another operation/request fingerprint: `409` with stable `code: idempotency_conflict`.
- Daily funding cap reached: `409` with stable `code: development_funding_daily_limit_reached` and no credit.
- Missing/invalid/revoked/expired session: existing `401` behavior.
- Rate limit: `429` with `Retry-After`.
- Expected transient database failure: generic `503`; no balance or success is fabricated.
- Outside Development: route is not mapped and returns `404`.

Every response under the development-funding path receives `Cache-Control: no-store`. Logs contain outcome/reason and opaque transaction/correlation identifiers only—not access tokens, idempotency keys, email addresses, display names, bodies, or raw database errors.

## 7. Data Model

### `LedgerTransactions`

- `Id` UUID primary key and opaque receipt reference.
- `Operation` constrained initially to `DEVELOPMENT_FUNDING`.
- `InitiatedByUserId` required Identity foreign key with restricted deletion.
- `IdempotencyKey` UUID.
- `RequestFingerprint` fixed-length server-generated hash for conflict detection and future transfer reuse.
- `Currency` constrained to `PHP`.
- `BalanceAfterMinor` non-negative bigint receipt snapshot.
- `CreatedAtUtc` required UTC timestamp.
- Unique index on `(InitiatedByUserId, IdempotencyKey)`.

### `LedgerPostings`

- `Id` UUID primary key.
- `LedgerTransactionId` required restricted foreign key.
- `Position` small integer; unique with transaction ID.
- `CustomerAccountId` nullable restricted foreign key.
- `BookAccount` nullable text constrained to `SIMULATOR_ISSUER`.
- `AmountMinor` signed non-zero bigint.
- `Currency` constrained to `PHP`.
- `CreatedAtUtc` matches its transaction timestamp.
- Check constraint: exactly one of `CustomerAccountId` or `BookAccount` is populated.

One funding transaction writes exactly two postings whose signed sum is zero:

```text
SIMULATOR_ISSUER                  -5,000,000 PHP minor units
authenticated customer account   +5,000,000 PHP minor units
                                            ----------
                                                     0
```

The journal is append-only through application behavior: no update/delete endpoint or service method is introduced. The database enforces structural constraints; service transaction boundaries and PostgreSQL integration tests enforce the two-posting zero-sum invariant.

### Existing account change

Replace `CK_CustomerAccounts_ZeroBalance` with `CK_CustomerAccounts_NonNegativeBalance` (`BalanceMinor >= 0`). Existing zero rows remain valid. No balance backfill, grant, user change, or automatic migration occurs.

## 8. Transaction and Concurrency Logic

```text
FUND_CURRENT_CUSTOMER(idempotencyKey):
  require Development environment, HTTPS, valid session, empty input and UUID key
  begin PostgreSQL transaction
  lock the authenticated customer's CustomerAccount row FOR UPDATE
  if account is missing:
    rollback and return account_not_opened
  find LedgerTransaction for current user + idempotencyKey
  if found with the same operation/fingerprint:
    commit read-only path and replay the original receipt
  if found with a different operation/fingerprint:
    rollback and return idempotency_conflict
  calculate the current Asia/Manila day as a half-open UTC range using the server clock
  sum committed DEVELOPMENT_FUNDING customer credits for this account in that range
  if another fixed grant exceeds the PHP 100,000 daily funding cap:
    rollback and return development_funding_daily_limit_reached
  checked-add PHP 50,000 to current non-negative account balance
  add transaction envelope and exactly two opposite postings
  save transaction, postings and balance in the same database transaction
  commit
  return persisted receipt
```

Locking the account row before checking idempotency/cap serializes concurrent funding attempts for that account. Daily calculations use an injected server clock and the `Asia/Manila` date boundary converted to UTC, so device time and locale cannot change the allowance. Slice 5 will lock source and destination accounts in deterministic UUID order to avoid deadlocks.

## 9. Minimal Flutter Diagnostics Flow

```text
Open API Diagnostics
  -> load System Info
  -> if environment is exactly Development and customer is authenticated:
       show "Development simulator funding" disclosure
       show "Add PHP 50,000 test funds" action
  -> otherwise do not show the action

Tap funding action
  -> show explicit fake-money confirmation
  -> generate one UUID idempotency key
  -> disable duplicate taps while pending
  -> POST using normal protected-session refresh/retry behavior
  -> timeout/uncertain retry reuses the same key
  -> success shows credited amount/reference and refreshes account state
  -> definitive 401 follows existing session invalidation
  -> cap/not-opened/rate/offline/server failures show distinct safe messages
```

The backend environment check is authoritative. A modified client cannot activate the endpoint outside Development or fund another account.

## 10. Security and Reliability Requirements

- Reuse the current bearer/session eligibility checks and trusted loopback forwarding rules.
- Derive the user/account exclusively from the authenticated server context.
- Map the endpoint only in Development; the `Testing` environment may map it solely inside automated test hosts.
- Add a dedicated low-volume fixed-window rate policy; proposed limit is 10 attempts/minute per client IP with no queue.
- Reject redirects, query input, non-empty JSON, unsupported content types, oversized/streamed bodies, and malformed idempotency keys.
- Use checked `long` arithmetic and PHP-only constraints; never accept floating-point or client-calculated totals.
- Calculate funding and future transfer daily windows on the server using `Asia/Manila`; never trust a client-supplied date, timezone, or current time.
- Commit account balance, transaction, and postings atomically; any failure rolls back all three.
- Preserve the original idempotency key for uncertain client retry, but never log it.
- Return generic dependency failures and fixed log templates.
- Run focused security review and migration safety review before implementation is considered ready for shared rollout.

## 11. Migration and Rollout Safety

The migration is additive except for replacing the zero-only account check with a non-negative check. It must:

1. drop only `CK_CustomerAccounts_ZeroBalance`;
2. add `CK_CustomerAccounts_NonNegativeBalance`;
3. create the two ledger tables, constraints, foreign keys, and indexes;
4. contain no user/account seed, balance update, funding event, or automatic execution;
5. preserve Identity, refresh-token, session, and existing account rows;
6. document that Down drops journal data and reinstates zero-only balance only if every balance is zero, making rollback destructive/unsafe after funding.

Required sequence:

1. generate and inspect migration after plan approval;
2. generate SQL and run migration/model tests;
3. use only a fresh explicitly named local disposable `banking_lab_ledger_test` database;
4. verify concurrency, rollback, constraints, and migration upgrade there;
5. obtain separate approval for backup/shared `banking_lab` migration;
6. take and verify a custom-format backup;
7. apply the reviewed migration once;
8. verify row counts, constraints, and unchanged authentication data;
9. fund Chris and Gio only through the API after each is authenticated in their own account.

No command may reset, drop, downgrade, or overwrite the shared database automatically.

## 12. Expected Files

Backend:

- `banking-lab/backend/Banking.api/Features/Ledger/LedgerTransaction.cs`
- `banking-lab/backend/Banking.api/Features/Ledger/LedgerPosting.cs`
- `banking-lab/backend/Banking.api/Features/Ledger/DevelopmentFundingContracts.cs`
- `banking-lab/backend/Banking.api/Features/Ledger/DevelopmentFundingRequestGuards.cs`
- `banking-lab/backend/Banking.api/Features/Ledger/DevelopmentFundingService.cs`
- `banking-lab/backend/Banking.api/Features/Ledger/DevelopmentFundingEndpoints.cs`
- `banking-lab/backend/Banking.api/Program.cs`
- `banking-lab/infrastructure/temporary/AppDbContext.cs`
- one generated migration plus model snapshot

Mobile:

- a small `features/development_funding/` data/repository/controller boundary
- `banking-lab/mobile/banking_mobile/lib/features/system_info/presentation/screens/system_info_screen.dart`
- account invalidation/refresh wiring without persisting financial data locally

Tests and canonical docs:

- database-free endpoint/service/guard tests
- disposable PostgreSQL migration, invariant, concurrency, cap, replay, and rollback tests
- Flutter service/controller/widget/accessibility tests
- OpenAPI endpoint coverage
- update the account contract or add a dedicated ledger/funding architecture contract
- walkthrough with exact .NET, Docker, disposable-test, migration-review, and phone commands

The implementation produced migration `20260908124011_AddLedgerAndDevelopmentFunding`; it is reviewed and disposable-tested but remains unapplied to shared `banking_lab`.

## 13. Test Strategy

### Database-free backend

- endpoint absent in Production and available in Development/test host only;
- HTTPS, no-store, bearer/session, input, idempotency-header, rate-limit, and safe-error behavior;
- self-only ownership and unopened-account conflict;
- first success and exact-key replay;
- different key grants again until the cap;
- daily-cap rejection, next-day reset boundary, and checked money boundaries;
- logs exclude credentials, identity fields, body, and key values;
- OpenAPI contains the endpoint only in allowed environments.

### Disposable PostgreSQL

- upgrade from the current account migration preserves users, sessions, tokens, accounts, and zero balances;
- new constraints reject invalid currency, negative balances, zero postings, invalid posting targets, orphan rows, and duplicate transaction/idempotency/position keys;
- one grant writes one transaction, two opposite postings, and one matching balance update;
- same-key concurrent calls create one logical grant and replay one receipt;
- different-key concurrent calls serialize correctly and cannot cross the PHP 100,000 daily cap;
- requests immediately before/after Philippine midnight are assigned to the correct half-open daily window using an injected clock;
- injected failure before commit leaves balance, transaction, and postings unchanged;
- journal sums and `CustomerAccounts.BalanceMinor` reconcile;
- generated SQL contains no seed or balance data update.

### Flutter

- funding card appears only for authenticated Development diagnostics;
- explicit confirmation and disclosure identify fake money;
- rapid taps send one request;
- uncertain retry reuses its UUID key;
- success refreshes the account and displays safe receipt feedback;
- 401, unopened, cap, 429, offline, timeout, and 503 remain distinguishable;
- Light/Dark, TalkBack, 320/360/412/768 widths, and 200% text remain usable.

## 14. Final Pass/Fail Acceptance Criteria

- [x] Automated API and disposable PostgreSQL tests prove an eligible customer can issue one fixed PHP 50,000 self-grant after rollout.
- [x] The caller cannot provide an amount, customer ID, account ID, currency, or recipient.
- [x] Each committed grant creates exactly one immutable transaction and two balanced PHP postings.
- [x] The account balance equals its committed customer posting total and never becomes negative.
- [x] The same customer/key replay never grants funds twice, including concurrent requests and timeout retry.
- [x] Distinct requests cannot exceed PHP 100,000 Development funding per account in one `Asia/Manila` calendar day; the allowance resets automatically on the next day.
- [x] Development funding is accounted separately and does not consume the future PHP 100,000 outgoing-transfer daily allowance.
- [ ] Slice 5 enforces at most PHP 50,000 per internal transfer and PHP 100,000 aggregate outgoing per source account per Philippine calendar day.
- [x] Production does not map the funding endpoint and returns 404.
- [x] All protected-path responses use no-store, secure transport, bounded input, rate limiting, safe errors, and existing session authorization.
- [x] Logs and responses do not expose secrets or unnecessary customer identity data within the reviewed Slice 4 scope.
- [x] Automated tests prove the Flutter Diagnostics trigger is Development/fake-money labeled, single-flight, confirmation-gated, compact/200%-text usable, and hidden while signed out; physical TalkBack remains post-rollout.
- [x] Database-free, Flutter, and fresh disposable PostgreSQL suites pass.
- [x] Migration operations/SQL are reviewed and contain no seed or balance data update.
- [x] Shared PostgreSQL remained untouched until separate post-test approval and a verified backup; only the reviewed migration was then applied.
- [ ] Chris and Gio each fund only their own account through the API and observe independently reconciled balances before Slice 5 begins.

## 15. Approval Gate

Approval of this draft authorizes implementation and automated tests against database-free and explicitly configured fresh disposable test infrastructure only. It does **not** authorize:

- applying the migration to shared `banking_lab`;
- crediting Chris or Gio;
- editing shared rows directly;
- creating Transfer/Activity/admin features;
- performing a destructive rollback.

Those shared-data actions require a later evidence-backed approval after the migration safety review and disposable PostgreSQL results.
