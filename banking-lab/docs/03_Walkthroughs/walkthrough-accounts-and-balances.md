# Customer Accounts and Balances Delivery

- Date: 2026-09-06.
- Status: Code, database-free checks, disposable PostgreSQL verification, backed-up shared schema rollout and the physical customer-A journey are complete. Cross-customer B isolation and TalkBack listening remain pending.
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
| `banking-lab/backend/Banking.api/Migrations/20260906042449_AddCustomerAccounts.cs` | Additive migration applied to the approved disposable and shared local databases; designer and snapshot accompany it. |
| `banking-lab/mobile/banking_mobile/lib/features/accounts/` | Summary parsing, protected API calls, repository, controller and card. Adjust card copy/spacing within simulator scope; preserve accessibility and integer formatting. |
| `banking-lab/mobile/banking_mobile/lib/features/home/presentation/screens/customer_home_screen.dart` | Account-card integration; existing greeting, diagnostics and logout remain. |
| `banking-lab/mobile/banking_mobile/lib/features/authentication/data/repositories/authentication_repository.dart` | Session generation and ordered secure-storage operations. |
| `banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/controllers/authentication_controller.dart` | Immediate signed-out UI, generation-aware invalidation and stale-operation suppression. |
| `banking-lab/backend/tests/Banking.IntegrationTests/CustomerAccountEndpointTests.cs` | API ownership/session/input/transport/rate/streaming/retry checks. |
| `banking-lab/backend/tests/Banking.IntegrationTests/CustomerAccountMigrationTests.cs` | Offline migration operations/SQL-shape/snapshot checks. |
| `banking-lab/backend/tests/Banking.IntegrationTests/PostgresAccountTests.cs` | Guarded real-PostgreSQL upgrade, concurrent opening and constraint tests; passed 4/4 against the approved disposable database. |
| `banking-lab/mobile/banking_mobile/test/features/accounts/` | Account contract/state/accessibility/layout/race checks; auth repository and app widget tests also cover affected journeys. |

## Executed verification

| Check | Confirmed result |
| --- | --- |
| Backend build, `--no-restore -m:1 -p:UseSharedCompilation=false` | Passed, zero warnings/errors. |
| Backend suite with both database-test environment variables unset | 196 passed, 0 failed, 10 skipped (six existing session tests, four new account tests). |
| Approved disposable PostgreSQL account fixture | 4 passed, 0 failed, 0 skipped against fresh `127.0.0.1:5432 / banking_lab_accounts_test`. |
| Approved shared `banking_lab` rollout | Verified pre-migration custom dump/catalog/hash, applied only `20260906042449_AddCustomerAccounts`, and passed schema/data/model post-checks. |
| Full Flutter test suite | 101 passed. |
| Flutter analysis | No issues found. |
| Account-card widget states | Unopened/loaded/error at 320, 360, 412 and 768 logical-pixel widths, with 200% text scaling; no overflow. Button size and focus/tap semantics checked. |
| Migration generation and SQL script generation | Succeeded and was reviewed before the later approved rollout. Forward SQL creates CustomerAccounts, its constraints and unique index, then records the migration in EF history. |
| Physical customer-A path | In-place APK update preserved app data; private HTTPS diagnostics, Mailpit registration/confirmation, login, unopened state, opening, persistence, API-outage Retry and logout passed. |
| Physical accessibility sample | At 200% system text, the long reference wrapped and Refresh/Sign out remained reachable by scrolling; the original 1.0 scale was restored. TalkBack spoken order remains pending. |
| Targeted whitespace and documentation checks | Completed at handoff; see task.md for final status. |

The first accessibility test run failed because of test semantics-handle cleanup and a missing expected focus action. The harness was corrected; the final full suite passed. Review also corrected first-create timestamp precision and preserved logout's ability to revoke a rotated token whose secure write was pending. Tests cover pending refresh/secure writes, cross-login late results, final account 401, and logout while an account request is pending.

Backend command from repository root (database variables must be unset for database-free execution):

```powershell
dotnet test banking-lab/backend/tests/Banking.IntegrationTests/Banking.IntegrationTests.csproj --no-restore -m:1 -p:UseSharedCompilation=false --verbosity quiet
```

Flutter equivalents from `banking-lab/mobile/banking_mobile`: `flutter analyze --no-pub` and `flutter test --no-pub`. This session used the installed Dart executable and Flutter tool snapshot directly. The initial .NET build emitted first-run development-certificate setup output; no certificate trust command was run. Later tooling commands disabled first-run certificate generation/telemetry where configured.

Docker/PostgreSQL were used for the approved disposable fixture, shared migration and physical-phone journey. No ZAP scan, database reset/deletion, push or commit rewrite was performed.

## Migration review and verified rollout

Risk is medium for rollout because durable account ownership adds a foreign key into identity. The reviewed forward SQL creates only the account table and index; no existing table alteration, data deletion, backfill or seed funding is present. Old code can retain the additive table; the new endpoints require it. Required columns/checks apply to the empty new table. Foreign-key DDL can take locks on the referenced identity table, so target activity and backup remain rollout considerations.

The fixture requires `BANKING_ACCOUNTS_TEST_DATABASE` to identify **banking_lab_accounts_test on local PostgreSQL**. It rejects other database names, non-loopback hosts and custom search paths. The approved target was **127.0.0.1:5432 / banking_lab_accounts_test**, using the existing PostgreSQL 17 service. It required a fresh approved database and performed no automatic reset/downgrade or cleanup.

Chris approved the named next step and started PostgreSQL. The target name was confirmed absent before creation, then fresh `banking_lab_accounts_test` was created on local PostgreSQL 17. `BANKING_AUTH_TEST_DATABASE` remained unset, credentials were loaded privately without being printed, and the guarded `PostgresAccountTests` filter passed 4/4. This verified upgrade preservation, concurrent opening, timestamp/retry equality, uniqueness, PHP/zero checks, orphan rejection and restricted deletion. A post-check found the account migration once in the disposable target and zero times in shared `banking_lab`.

The disposable database remains intact with fake test evidence. Do not reset/delete it automatically. The fixture deliberately refuses an already migrated database, so a repeat of the fresh-upgrade test requires a newly reviewed target or an explicitly approved cleanup/recreation procedure.

Chris explicitly approved backup and application of only `20260906042449_AddCustomerAccounts` to shared `127.0.0.1:5432 / banking_lab`. Preflight confirmed PostgreSQL 17.11, no other shared-database connection, no API listener, 2 users, 3 sessions, 4 refresh tokens, no account table and migrations through AddCustomerSessions only. The 8,255,155-byte database was small, but the rollout retained the medium-risk classification because the new table represents durable financial ownership.

Custom-format backup `banking_lab/.local/backups/banking_lab_pre_AddCustomerAccounts_20260906T134746Z.dump` is 25,133 bytes with SHA-256 `e370fb10aab9f95e307e8882eff1fc0d649a2ca8e81dd39ae707325081c2b871`. `pg_restore --list` read 76 entries, included the existing identity schema and excluded CustomerAccounts as expected. A process-scoped connection string pinned EF to the approved host/database. Generated forward SQL contained the expected table, constraints, unique index and history insert, with no DROP, DELETE, TRUNCATE or UPDATE statement.

The named migration completed successfully. Post-checks found one history marker, zero account rows, unchanged user/session/token counts, both PHP/zero CHECK constraints, restricted owner FK, unique owner index and no pending EF model changes. The verified backup remains the recovery point. The Down migration drops account data; prefer retaining the additive table during application rollback, and approve any schema/data recovery separately. Production deployment remains outside this delivery.

## Physical-phone verification

The Infinix Android device received the current debug APK with `adb install -r`, preserving the installation/data directory. Tailscale initially reported `NoState` even though its Windows service was running; starting the tray client restored the existing tailnet identity, after which Serve privately forwarded HTTPS port 443 to the loopback-only `http://127.0.0.1:5255` origin. Both the PC and phone diagnostics returned the development Banking API response. No private hostname is committed.

The two earlier fake identities had no recoverable plaintext passwords, as expected for password hashing. Chris therefore registered a new fake customer on the phone. Mailpit captured the message at its loopback-only PC inbox, [http://localhost:8025](http://localhost:8025). The one-use link target and parameter shapes were validated, its token was kept out of output, and confirmation returned HTTP 204. Mailpit is a development inbox, not delivery to a public mailbox; its messages may disappear if the container is recreated.

After login, Home showed the explicit unopened state and simulator wording. The first automated tap attempt did **not** open an account: its coordinate calculation concatenated strings, while its assertion incorrectly matched `PHP 0.00` inside the explanatory sentence. Screenshot review caught the false positive. The corrected check used numeric coordinates plus the real persisted reference/Refresh state. The successful action created exactly one row; database checks independently confirmed one unique owner, PHP currency, zero minor units and a non-null opening time.

Force-stop/relaunch restored both the authenticated session and the exact account reference. Stopping only the API made Refresh show a recoverable server error and Retry—never a fabricated zero balance or unopened state. Restarting the API and tapping Retry restored the exact same reference. At 200% system text, the long reference wrapped, the screen remained scrollable and Refresh/Sign out were reachable; the original 1.0 system scale was restored in the same guarded procedure.

Server-backed sign-out reached Login. A second force-stop/relaunch stayed at Login with no stale account reference. PostgreSQL then showed 4 historical session rows and 10 historical refresh-token rows but 0 active sessions/tokens; the single account remained intact at zero balance. Historical rows are retained security evidence, not active logins.

### Remaining physical checks

- Cross-customer B isolation still needs either an additional approved fake-customer write or another known test credential entered locally. Automated repository tests already cover late account work across logout/login generations, but that does not replace the physical A/B observation.
- TalkBack spoken reading order requires Chris to listen on the device. XML/semantics inspection and widget focus tests cannot truthfully substitute for that human check.
- A deliberately delayed in-flight request was not injected into the shared runtime. The widget suite covers logout while an account request is pending; physical testing covered ordinary server-backed logout, restart isolation and the separate outage/Retry state.

## Focused security review

Reviewed the new account endpoints/query filters, request guards, minimal DTOs, migrations, mobile token handling, redirect policy, error paths and session/storage races. No unresolved high/critical finding was identified within this source-review scope. That is not a full repository audit or a ZAP result. The material remaining physical gaps are cross-customer B isolation and TalkBack listening; do not label those checks passed until observed.
