# Customer Accounts and Balances Delivery

- Date: 2026-09-06.
- Status: Code and database-free verification complete. PostgreSQL tests, migration rollout and physical-phone acceptance remain pending explicit approval.
- Approved behavior: One PHP simulator account per customer, opened explicitly at PHP 0.00; funding/transfers separate.
- Canonical behavior: [accounts contract](../04_Architecture/customer-accounts-contract.md).
- Current execution and approvals: [task.md](../01_Tracking/task.md).

## How the feature works

1. A signed-in customer opens Home. The account controller gets an access token through the existing authentication repository and requests the owner's account.
2. The API enforces secure transport, bounded input and request limits, then validates the bearer token against the persisted session/customer. It queries by the server-validated owner.
3. An unopened account is a specific response code, so outages and other missing resources cannot accidentally enable account creation.
4. Open account sends an empty PUT. The backend supplies every persisted value and inserts exactly one account per owner. A repeat returns the existing row; a concurrent unique-owner collision reads the committed winner. Reading back the first insert also normalizes PostgreSQL timestamp precision.
5. Home displays the persisted summary. If opening times out, Retry checks GET first before potentially repeating PUT. No fake balance is substituted for a failure.
6. A final authentication rejection redirects to sign-in. Logout/user switching invalidates pending responses. A serialized secure-storage queue ensures a late token write cannot overwrite a newer login or survive logout cleanup.

## Concepts

- **Ownership authorization:** A valid login proves who the caller is; a server-side owner filter determines which record they may access. Hiding another user's data in Flutter alone would not enforce ownership.
- **Idempotency:** Repeating the same opening action has the same lasting result: one account with the same identity and opening time. This makes retries after uncertain network results safe.
- **Minor units:** Monetary values use whole centavos instead of floating-point pesos. The API's integer string and Dart BigInt preserve exact digits.
- **Session generation:** Each new login/logout/invalidation changes a counter. Work started under an older counter cannot update the current session or account UI.
- **Additive migration:** The forward migration adds a new table without rewriting existing customer data. Its Down operation can still be destructive because it drops the new records.

## Main repository paths and customization

| Repository path | Purpose / safe customization |
| --- | --- |
| `banking-lab/backend/Banking.api/Features/Accounts/CustomerAccount.cs` | Account entity; ownership/currency/zero invariants require a new reviewed plan to change. |
| `banking-lab/backend/Banking.api/Features/Accounts/CustomerAccountService.cs` | Owner-filtered read, idempotent opening and named uniqueness-race recovery. |
| `banking-lab/backend/Banking.api/Features/Accounts/CustomerAccountEndpoints.cs` | Minimal DTO responses and safe error classification. |
| `banking-lab/backend/Banking.api/Features/Accounts/AccountRequestGuards.cs` | HTTPS, cache, rate and bounded-input checks. Do not relax these to fix connectivity. |
| `banking-lab/infrastructure/temporary/AppDbContext.cs` | DbSet and database constraints in the existing context location. |
| `banking-lab/backend/Banking.api/Migrations/20260906042449_AddCustomerAccounts.cs` | Generated, unapplied additive migration; designer and snapshot accompany it. |
| `banking-lab/mobile/banking_mobile/lib/features/accounts/` | Summary parsing, protected API calls, repository, controller and card. Adjust card copy/spacing within simulator scope; preserve accessibility and integer formatting. |
| `banking-lab/mobile/banking_mobile/lib/features/home/presentation/screens/customer_home_screen.dart` | Account-card integration; existing greeting, diagnostics and logout remain. |
| `banking-lab/mobile/banking_mobile/lib/features/authentication/data/repositories/authentication_repository.dart` | Session generation and ordered secure-storage operations. |
| `banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/controllers/authentication_controller.dart` | Immediate signed-out UI, generation-aware invalidation and stale-operation suppression. |
| `banking-lab/backend/tests/Banking.IntegrationTests/CustomerAccountEndpointTests.cs` | API ownership/session/input/transport/rate/streaming/retry checks. |
| `banking-lab/backend/tests/Banking.IntegrationTests/CustomerAccountMigrationTests.cs` | Offline migration operations/SQL-shape/snapshot checks. |
| `banking-lab/backend/tests/Banking.IntegrationTests/PostgresAccountTests.cs` | Guarded real-PostgreSQL upgrade, concurrent opening and constraint tests; not executed yet. |
| `banking-lab/mobile/banking_mobile/test/features/accounts/` | Account contract/state/accessibility/layout/race checks; auth repository and app widget tests also cover affected journeys. |

## Executed verification

| Check | Confirmed result |
| --- | --- |
| Backend build, `--no-restore -m:1 -p:UseSharedCompilation=false` | Passed, zero warnings/errors. |
| Backend suite with both database-test environment variables unset | 196 passed, 0 failed, 10 skipped (six existing session tests, four new account tests). |
| Full Flutter test suite | 101 passed. |
| Flutter analysis | No issues found. |
| Account-card widget states | Unopened/loaded/error at 320, 360, 412 and 768 logical-pixel widths, with 200% text scaling; no overflow. Button size and focus/tap semantics checked. |
| Migration generation and SQL script generation | Succeeded without applying a migration. Forward SQL creates CustomerAccounts, its constraints and unique index, then records the migration in EF history. |
| Targeted whitespace and documentation checks | Completed at handoff; see task.md for final status. |

The first accessibility test run failed because of test semantics-handle cleanup and a missing expected focus action. The harness was corrected; the final full suite passed. Review also corrected first-create timestamp precision and preserved logout's ability to revoke a rotated token whose secure write was pending. Tests cover pending refresh/secure writes, cross-login late results, final account 401, and logout while an account request is pending.

Backend command from repository root (database variables must be unset for database-free execution):

```powershell
dotnet test banking-lab/backend/tests/Banking.IntegrationTests/Banking.IntegrationTests.csproj --no-restore -m:1 -p:UseSharedCompilation=false --verbosity quiet
```

Flutter equivalents from `banking-lab/mobile/banking_mobile`: `flutter analyze --no-pub` and `flutter test --no-pub`. This session used the installed Dart executable and Flutter tool snapshot directly. The initial .NET build emitted first-run development-certificate setup output; no certificate trust command was run. Later tooling commands disabled first-run certificate generation/telemetry where configured.

No ZAP scan, Docker/service startup, live HTTP verification, database migration execution, database reset, Git write or physical-phone test was performed.

## Migration review and exact next approval

Risk is medium for rollout because durable account ownership adds a foreign key into identity. The reviewed forward SQL creates only the account table and index; no existing table alteration, data deletion, backfill or seed funding is present. Old code can retain the additive table; the new endpoints require it. Required columns/checks apply to the empty new table. Foreign-key DDL can take locks on the referenced identity table, so target activity and backup remain rollout considerations.

The new fixture requires `BANKING_ACCOUNTS_TEST_DATABASE` to identify **banking_lab_accounts_test on local PostgreSQL**. It rejects other database names, non-loopback hosts and custom search paths. The proposed target is **127.0.0.1:5432 / banking_lab_accounts_test**, using the existing PostgreSQL 17 service. It requires a fresh approved database and performs no automatic reset/downgrade or cleanup. Before creating it, verify whether it exists; if occupied, stop for review rather than deleting it.

After explicit approval to start the local PostgreSQL service, create/use that fresh disposable target and run its fixture:

1. Configure the test connection privately; never echo credentials. Leave `BANKING_AUTH_TEST_DATABASE` unset so this run does not also execute the separate session fixture.
2. The accounts fixture applies migrations up to AddCustomerSessions, seeds fake identity/session evidence, then applies AddCustomerAccounts.
3. Run `dotnet test banking-lab/backend/tests/Banking.IntegrationTests/Banking.IntegrationTests.csproj --no-restore --filter FullyQualifiedName~PostgresAccountTests` with the approved accounts test variable set only for that process.
4. Verify upgrade preservation, concurrent opening (separate DbContexts), timestamp/retry equality, uniqueness, PHP/zero checks, orphan rejection and restricted deletion. Record real results before considering shared rollout.
5. Do not reset/delete the disposable database afterward without approval. A rerun of the fresh-upgrade fixture requires a separately reviewed fresh target state; the fixture deliberately refuses an already migrated database.

The shared `banking_lab` database has not been inspected or changed. Shared rollout requires its own exact-target approval and verified backup, SQL review, then application of only the account migration. The Down migration drops account data; prefer retaining the table on application rollback, and approve any schema/data recovery separately. Production deployment remains outside this delivery.

## Pending physical-phone and visual checks

After approved database rollout and runtime setup:

1. Start the approved API/PostgreSQL services and existing trusted Tailscale HTTPS path. Sign in as fake customer A on the Infinix Android phone. Confirm unopened state and simulator wording.
2. Tap Open account. Confirm PHP 0.00 and a simulator reference. Repeat/retry the opening request in the approved local test flow; verify one row and unchanged ID/time.
3. Restart the app and sign in/restore. Confirm the same account. Disable connectivity, refresh, and confirm a recoverable error rather than invented zero/unopened state. Restore connectivity and Retry.
4. Sign out during a delayed account request and sign in as fake customer B. Confirm A's data never reappears and B has an independent account/unopened state.
5. In the isolated environment, verify final-session rejection routes to Login while dependency failures preserve Retry.
6. Check actual phone contrast, 200% text, focus, TalkBack reading order, long reference wrapping, scroll reachability and touch targets. Widget checks do not substitute for these physical observations.

## Focused security review

Reviewed the new account endpoints/query filters, request guards, minimal DTOs, migrations, mobile token handling, redirect policy, error paths and session/storage races. No unresolved high/critical finding was identified within this source-review scope. That is not a full repository audit or a ZAP result. The material remaining verification gap is PostgreSQL execution and device rollout; do not label the slice verified end to end until those gates pass.
