# Slice 5 Walkthrough: Internal Fake-Money Transfer API

- Date: 2026-09-09.
- Delivery state: Backend candidate implemented; database-free, migration-shape, fresh disposable PostgreSQL, and Flutter regressions passed. Shared migration, live transfer, Flutter Transfer UI, and active ZAP remain gated.
- Contract: [internal transfer](../04_Architecture/internal-transfer-contract.md).
- Plan: [Slice 5](../02_Planning/plan-kk10p-slice-5-internal-transfer-api.md).

## Delivered outcome

Slice 5 adds the server-authoritative operation needed for Chris and Gio to transfer fake PHP after the later shared rollout and Slice 6 UI. The endpoint derives the source from the authenticated persisted session, accepts only another account reference plus canonical centavos, and enforces PHP 50,000 per transfer and PHP 100,000 outgoing per Philippine day.

One PostgreSQL transaction locks both accounts in one deterministic order, checks idempotency/limits/funds, updates both balance snapshots, and appends an equal-and-opposite customer posting pair. Same-key retries return the original receipt. Every transfer response is no-store and correlated; logs contain outcome, duration, and an optional committed transaction ID without request money, customer data, account references, keys, or tokens.

## Concepts used in this slice

- **Authenticated ownership:** server session state selects the source; client JSON never can.
- **Atomic value conservation:** both snapshots and both journal postings commit or roll back together.
- **Deterministic pessimistic locking:** database UUID ordering prevents opposite-direction lock inversion.
- **Cross-operation idempotency:** one user/key namespace prevents a funding key from becoming a transfer key.
- **Canonical minor units:** strict integer strings avoid float rounding and ambiguous request fingerprints.
- **Business-day accounting:** server time defines the half-open Manila-day outgoing window.
- **Defense in depth:** HTTPS, exact shape, bounded streams, no query, auth, rate limit, safe errors, constraints, and append-only EF checks each enforce a separate boundary.
- **Correlation without disclosure:** a generated request ID connects client-safe errors with structured diagnostics.

## Logic flow

```text
POST /api/v1/transfers/internal
  -> generate request ID + no-store
  -> validate HTTPS, route, query, media, 16 KiB, key, exact JSON
  -> validate bearer and persisted eligible session
  -> find source only by authenticated user
  -> begin transaction and lock both UUIDs in one order
  -> exact replay or idempotency conflict
  -> reject self/missing recipient
  -> calculate Manila-day committed outgoing total
  -> reject daily cap or insufficient funds
  -> checked debit source + credit destination
  -> append INTERNAL_TRANSFER + two balanced customer postings
  -> commit and return persisted receipt

Cancellation/uncertain network result
  -> client must retry the same logical request with the same UUID key
```

## Important repository paths

| Path | Purpose / safe customization |
| --- | --- |
| `banking-lab/backend/Banking.api/Features/Transfers/` | Contract, exact guards, service, outcome mapping, and safe transfer logging. Limit changes require policy and concurrency-test review. |
| `banking-lab/backend/Banking.api/Observability/RequestCorrelationMiddleware.cs` | Generates `X-Request-ID`, opens its log scope, and times transfer-path requests. It deliberately ignores caller IDs. |
| `banking-lab/backend/Banking.api/Features/Ledger/LedgerTransaction.cs` | Defines the only allowed application operation names. |
| `banking-lab/infrastructure/temporary/AppDbContext.cs` | Ledger allow-list plus balance, posting, relationship, and append-only invariants. |
| `banking-lab/backend/Banking.api/Migrations/20260909065721_AddInternalTransfers.cs` | Constraint-only candidate. Do not apply to shared data without the next approval gate. |
| `banking-lab/backend/tests/Banking.IntegrationTests/InternalTransferEndpointTests.cs` | Fast contract, auth, error, privacy, log, and no-partial-write checks. |
| `banking-lab/backend/tests/Banking.IntegrationTests/PostgresInternalTransferTests.cs` | Opt-in fresh PostgreSQL upgrade, atomicity, concurrency, deadlock, and constraint proof. |
| `banking-lab/docs/04_Architecture/internal-transfer-contract.md` | Canonical implemented API/data/release contract for Slice 6. |

## Normal development commands

Run from repository root in PowerShell. Start PostgreSQL/Mailpit:

```powershell
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml --profile email up -d postgres mailpit
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml --profile email ps
```

Start the API from `banking-lab/backend/Banking.api`:

```powershell
dotnet run --launch-profile http
```

The current API listener may remain available for existing Slice 4 behavior, but the new transfer endpoint must not be exercised against shared `banking_lab` until migration approval/application. The phone continues to use the approved private HTTPS proxy URL, not direct LAN HTTP.

Run Flutter from `banking-lab/mobile/banking_mobile`:

```powershell
flutter run --dart-define=API_BASE_URL=https://YOUR-APPROVED-HTTPS-HOST
```

Slice 5 changes no Flutter source, so there is no transfer screen to test yet.

## Verification commands

Backend build and ordinary suite from `banking-lab/backend`:

```powershell
dotnet build Banking.slnx -c Release --no-restore
Remove-Item Env:BANKING_TRANSFER_TEST_DATABASE -ErrorAction SilentlyContinue
dotnet test Banking.slnx -c Release --no-restore
```

Inspect the exact generated migration SQL without applying it:

```powershell
dotnet ef migrations script 20260908124011_AddLedgerAndDevelopmentFunding 20260909065721_AddInternalTransfers --project Banking.api/Banking.api.csproj --startup-project Banking.api/Banking.api.csproj --context AppDbContext --configuration Release
```

The opt-in fixture accepts only `127.0.0.1`/`localhost`, database `banking_lab_transfer_test`, and the default search path. Create/drop only that disposable database after authorization:

```powershell
docker exec compose-postgres-1 createdb -U banking_app banking_lab_transfer_test
$env:BANKING_TRANSFER_TEST_DATABASE = 'Host=127.0.0.1;Port=5432;Database=banking_lab_transfer_test;Username=banking_app;Password=YOUR_LOCAL_TEST_PASSWORD'
dotnet test tests/Banking.IntegrationTests/Banking.IntegrationTests.csproj -c Release --no-restore --filter 'FullyQualifiedName~PostgresInternalTransferTests'
Remove-Item Env:BANKING_TRANSFER_TEST_DATABASE
docker exec compose-postgres-1 dropdb -U banking_app --if-exists banking_lab_transfer_test
```

The fixture itself never resets/drops a database and rejects an already-migrated target.

Flutter regressions from `banking-lab/mobile/banking_mobile`:

```powershell
flutter analyze
flutter test --reporter compact
```

## Verified results

| Check | Result |
| --- | --- |
| Release build | Passed, 0 warnings and 0 errors |
| Focused endpoint/model/migration tests | 32 passed initially; expanded transfer/migration suite passed 25/25 after accountless/revoked/storage cases were added |
| Complete ordinary backend suite | 234 passed, 0 failed; 20 opt-in PostgreSQL tests skipped without their explicit variables |
| Fresh `banking_lab_transfer_test` | 6 passed, 0 failed/skipped; database removed afterward |
| Migration SQL | Only drop/re-add of `CK_LedgerTransactions_Operation` plus EF history marker; no data rewrite |
| Flutter analysis | No issues |
| Flutter complete suite | 177 passed |
| Diff whitespace check | Passed |
| Shared `banking_lab` | Not migrated or written by Slice 5 implementation/proof |
| Local API listener | Existing loopback listener remained running on port 5255 |

One first disposable run reached the existing login route's shared per-IP test budget because the six database cases reuse one TestServer client address. The PostgreSQL-only host now assigns a unique synthetic connection address per request so unrelated login/transfer limiter state cannot leak between cases. Production rate-limit behavior was not weakened; the ordinary endpoint suite still verifies the real 10/minute transfer budget and `Retry-After`.

## Migration safety review

Forward risk is low in shape and medium in consequence because it changes which durable ledger operations PostgreSQL permits. The migration replaces one check with an explicit two-value allow-list. Existing funding rows satisfy it, which the fresh upgrade test proves. No table/column/index/foreign key/data changes are present.

Do not run Down after an internal transfer exists: narrowing the check back to funding-only will fail unless transfer records are destructively removed. Normal application rollback retains the widened schema. Shared rollout requires a fresh verified backup, quiesced API, before/after counts/sums/constraint checks, and separate approval.

## Scoped security and privacy review

Reviewed ownership derivation, persisted-session eligibility, recipient opacity, canonical UUID/amount parsing, duplicate/unknown JSON, streamed-body limits, HTTPS and no redirects, no-store, rate budget, checked arithmetic, daily window, lock ordering, replay/conflict ordering, transaction rollback, journal balance, exception mapping, correlation, and structured log content.

No unresolved high/critical issue was found in this Slice 5 source/test scope. This is not a production-readiness or penetration-test claim. The authenticated safe-then-active ZAP Gate B remains unexecuted and needs separate scan/disposable-data approval.

## Limitations and next steps

- No shared migration, authenticated live transfer, Flutter Transfer UI, Activity/history, admin portal, app lock, Cloudflare tunnel, or active ZAP was performed.
- Request correlation is currently in-process diagnostic context; centralized retention/alerts remain the later observability slice.
- Next gate: approve the exact shared migration rollout after backup/reconciliation, then implement Slice 6 recipient/amount/review/receipt UI with same-key uncertainty recovery.
