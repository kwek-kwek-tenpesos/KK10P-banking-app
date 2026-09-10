# Slice 7 Walkthrough: Activity, History, and Historical Receipts

- Date: 2026-09-10.
- Delivery state: Implementation and shared Gate 7R are complete. Automated, disposable PostgreSQL, shared rollout, and authenticated read-only smoke gates pass; Chris/Gio device acceptance remains pending.
- Plan: [Slice 7](../02_Planning/plan-kk10p-slice-7-activity-history-receipts.md).
- Contract: [Activity and historical receipts](../04_Architecture/activity-history-contract.md).

## Delivered outcome

An authenticated customer with an open simulator account can open Activity from Home, read only their own committed funding and transfer entries, filter by direction or type, page through stable history, and open a full-screen historical receipt. The UI uses the accepted KK10P neumorphic theme and contains no prototype transactions or unsupported controls.

The backend derives ownership from the authenticated session, projects immutable balanced journals, and fails closed if a committed journal is malformed. List rows disclose only a counterparty suffix; detail authorization makes another customer's transaction indistinguishable from a missing one. Activity reads cannot change the ledger or account balance.

The implementation phase did not touch shared `banking_lab`. The separately approved Gate 7R later added only the Activity index and EF history marker after a verified backup; it created no funding or transfer. Slice 7 did not run ZAP, change the theme, work on the admin panel/tunnel, or push.

## Concepts used in this slice

- **Owner-derived reads:** the authenticated customer selects the account; request data cannot select another owner.
- **Immutable keyset pagination:** UTC timestamp plus transaction UUID gives deterministic continuation without offset drift.
- **Fail-closed projection:** only exact, balanced two-posting funding/transfer journals become Activity rows.
- **Exact money:** canonical integer centavos remain `BigInt`/integer values until display formatting.
- **Privacy-preserving detail:** missing and non-owned transactions return the same safe result.
- **Strict server truth:** unknown fields, bad enums, malformed UUIDs/cursors, non-PHP values, and invalid UTC times are rejected.
- **Session-safe state:** one refresh is allowed; late reads cannot cross customer/session generations.
- **Non-destructive failure:** refresh or load-more errors retain already visible history and offer retry.

## Logic flow

```text
Loaded Home account
  -> open protected /activity
  -> GET current account transaction page
       -> backend derives account from authenticated owner
       -> filters immutable postings
       -> validates paired zero-sum journal
       -> returns server-authored rows + opaque next cursor
  -> group rows by local date and render explicit direction/status/amount
  -> optional compact direction/type filter resets to page one
  -> explicit Load more continues from the opaque cursor
  -> tap one row
       -> open protected /activity/:transactionId
       -> fetch that owner-scoped transaction
       -> render full historical receipt without invented balance-after
```

Successful Development funding or an internal transfer invalidates Activity so the next visible read begins from page one.

## Important repository paths

| Path | Purpose |
| --- | --- |
| `banking-lab/backend/Banking.api/Features/Activity/` | Strict query/cursor contracts, transport/rate guards, owner-scoped projection, and endpoints. |
| `banking-lab/backend/Banking.api/Migrations/20260910054031_AddActivityHistoryIndex.cs` | Additive posting-history index candidate. |
| `banking-lab/backend/tests/Banking.IntegrationTests/ActivityEndpointTests.cs` | Contract, ownership, privacy, paging, caching, transport, and failure coverage. |
| `banking-lab/backend/tests/Banking.IntegrationTests/PostgresActivityTests.cs` | Opt-in fresh PostgreSQL upgrade/index/pagination/read-only proof. |
| `banking-lab/mobile/banking_mobile/lib/features/activity/` | Strict data layer, controllers, list, compact filters, row card, and receipt screen. |
| `banking-lab/mobile/banking_mobile/lib/app/app_router.dart` | Protected `/activity` and `/activity/:transactionId` routes. |
| `banking-lab/mobile/banking_mobile/test/features/activity/` | Data, refresh, paging, responsive, filter, and receipt tests. |
| `banking-lab/mobile/banking_mobile/test/widget_test.dart` | Signed-out Activity deep-link protection. |

## Automated verification

Backend, from `banking-lab/backend`:

```powershell
dotnet test Banking.slnx -c Release --no-restore
```

Result: 254 passed, 0 failed, 21 opt-in PostgreSQL tests skipped as designed.

Flutter, from `banking-lab/mobile/banking_mobile`:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/features/activity test/widget_test.dart --reporter compact
flutter test --reporter compact
```

Results: analysis found no issues; focused Activity/app tests passed 23/23; the complete suite passed 217/217.

The opt-in Activity PostgreSQL test was run only against an exact fresh local database whose name ends in `_test`. It upgraded through representative funding/transfers, applied the candidate index, verified cursor continuation and unchanged row/balance counts, then removed the database. Result: 1 passed, 0 failed.

```powershell
Set-Location D:\OtherProjects\KK10P-banking-app\banking-lab\backend
$dbName = 'banking_lab_activity_test'
$existingDatabase = @(
  docker exec compose-postgres-1 psql -U banking_app -d postgres -Atc `
    "SELECT datname FROM pg_database WHERE datname = '$dbName';"
) -join ''

if ($existingDatabase.Trim() -ne '') {
  throw "Refusing to reuse existing database '$dbName'."
}

docker exec compose-postgres-1 createdb -U banking_app $dbName

try {
  # Capture the existing local container credential without printing or committing it.
  $pwLine = docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' compose-postgres-1 |
    Where-Object { $_.StartsWith('POSTGRES_PASSWORD=') }
  $dbPassword = $pwLine.Substring('POSTGRES_PASSWORD='.Length)
  $env:BANKING_ACTIVITY_TEST_DATABASE = "Host=127.0.0.1;Port=5432;Database=$dbName;Username=banking_app;Password=$dbPassword"

  dotnet test .\tests\Banking.IntegrationTests\Banking.IntegrationTests.csproj `
    -c Release --no-restore `
    --filter "FullyQualifiedName~PostgresActivityTests"
}
finally {
  Remove-Item Env:BANKING_ACTIVITY_TEST_DATABASE -ErrorAction SilentlyContinue
  docker exec compose-postgres-1 dropdb -U banking_app --force $dbName
}
```

Never substitute shared `banking_lab`, and keep cleanup limited to the exact disposable target.

## Start the normal development stack after Gate 7R

From repository root:

```powershell
docker compose -f .\banking-lab\infrastructure\compose\compose.dev.yml --profile email up -d postgres mailpit
docker compose -f .\banking-lab\infrastructure\compose\compose.dev.yml --profile email ps
```

In a second PowerShell window:

```powershell
Set-Location D:\OtherProjects\KK10P-banking-app\banking-lab\backend\Banking.api
dotnet run --launch-profile http
```

In a third PowerShell window:

```powershell
Set-Location D:\OtherProjects\KK10P-banking-app\banking-lab\mobile\banking_mobile
flutter devices
flutter run -d YOUR_DEVICE_ID --dart-define=API_BASE_URL=https://YOUR-APPROVED-HTTPS-HOST
```

Do not commit a device ID, private hostname, password, token, account reference, or receipt screenshot containing sensitive test details. While Flutter is running, type `r` for hot reload, `R` for hot restart, and `q` to stop.

## Gate 7R: completed

Gate 7R created and verified a fresh shared backup, recorded pre-migration counts/balances/journal invariants, confirmed the API was quiesced, applied only `20260910054031_AddActivityHistoryIndex`, verified the exact index and unchanged data, restarted the API, and passed read-only authenticated list/detail smoke checks. Normal PostgreSQL index creation can briefly lock writes, so quiescence remained the safe rollout path even for this small table.

No new funding or transfer was executed. Existing reconciled Slice 6 entries provided the Activity proof. Full backup, migration-safety, reconciliation, and smoke evidence is recorded in the [Gate 7R rollout report](walkthrough-kk10p-gate-7r-shared-activity-index-rollout.md). This delivery is committed only after the gate passed, before Gio pulls/builds.

## Chris/Gio phone checklist after Gate 7R and commit

1. Pull the committed Slice 7 change, start the normal stack, and sign in separately as Chris and Gio.
2. From a loaded Home account, open `View activity`; confirm existing funding and transfers match each customer's own known history.
3. Confirm outgoing/incoming direction, signed PHP amount, `Completed`, local date group, and masked counterparty are understandable.
4. Apply and clear the compact direction/type filters; confirm no search/status/test-state controls appear.
5. Open a transfer receipt and a funding receipt. Confirm references, local time, explicit UTC server time, and simulator wording match server data; no historical balance-after is shown.
6. Confirm one customer cannot see the other's unrelated receipt. A copied non-owned detail deep link must show the same not-found state as a random valid UUID.
7. Tap Refresh and Load more quickly; confirm no duplicate rows, crash, lost visible history, or repeated logical request.
8. Check Light/Dark, 320-ish split-screen width, 200% text, scrolling, Back behavior, and TalkBack reading order/labels.
9. With the API briefly unavailable, confirm existing history remains visible on refresh failure and Retry works after restoration.
10. Report screenshots or wording/layout issues only; do not create more money movement unless separately agreed.

## Recovery notes

- Before shared rollout, remove or amend the unapplied migration source normally; shared data is unaffected.
- After successful rollout, application code can be reverted while the unused additive index safely remains.
- Dropping the index is structurally simple but still requires a separately reviewed migration/rollback action. Never restore/reset shared data merely to remove this feature.
