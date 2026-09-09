# Slice 4 Walkthrough: Ledger and Development Funding

- Date: 2026-09-09.
- Delivery state: Completed and physically verified by Chris and Gio; database-free, Flutter, migration-shape, fresh disposable PostgreSQL, verified backup, shared rollout, authenticated funding reconciliation, and corrected non-zero Home rendering all passed.
- Contract: [ledger and Development funding](../04_Architecture/ledger-development-funding-contract.md).
- Plan: [Slice 4](../02_Planning/plan-kk10p-slice-4-ledger-development-funding.md).

## Delivered outcome

Slice 4 adds an auditable fake-money foundation rather than editing balances directly. An authenticated Development customer can request a fixed PHP 50,000 self-grant after the reviewed migration is later applied. One atomic transaction updates the account and appends an issuer/customer posting pair. UUID idempotency, an account row lock, and the PHP 100,000 Philippine-day cap prevent duplicate or excessive credit under retries and concurrency.

Flutter adds only a Development Diagnostics card. It is hidden when signed out or when the server is not Development, explains that funds are not real, requires confirmation, remains single-flight during rapid taps, and reuses its request key after uncertainty.

The approved shared rollout added only the ledger schema and non-negative balance constraint; it did not issue funds or alter existing identity/session/account rows. No transfer, Activity screen, administrator feature, React prototype, WebAuthn/passkey feature, tunnel replacement, or Production route changed.

## Concepts used in this slice

- **Double-entry journal:** every value movement has equal opposite signed postings, so a transaction sums to zero.
- **Balance snapshot plus journal:** `CustomerAccounts.BalanceMinor` makes current reads simple; postings provide the auditable source for reconciliation.
- **Idempotency:** retrying the same logical request returns the original result rather than repeating its effect.
- **Pessimistic serialization:** PostgreSQL `FOR UPDATE` makes grant/cap decisions for one account execute in a safe order.
- **Business-day window:** Manila midnight is converted to a half-open UTC range; phone time cannot alter limits.
- **Append-only behavior:** EF blocks journal mutation/deletion and PostgreSQL restricts structure/relationships.
- **Environment fail-closed:** Production does not map the route. Hiding the Flutter card is not authorization.
- **Integer minor units:** centavos use checked 64-bit integers on the server and strict integer strings over JSON.

## Logic flow

```text
Diagnostics receives environment=Development + authenticated customer
  -> show fixed-grant disclosure
  -> user confirms
  -> create UUID and disable duplicate taps
  -> POST {} with bearer + Idempotency-Key over HTTPS
  -> API validates transport/input/session
  -> lock current customer's opened account
  -> replay same key, or calculate today's Manila-window grants
  -> reject if missing account/cap exceeded
  -> checked-add balance + append two balanced postings
  -> commit once
  -> show result and refresh Home account state

Uncertain timeout/network/503
  -> keep UUID
  -> Retry same request
  -> receive original committed result or safely create it once
```

## Important repository paths

| Path | Purpose / safe customization |
| --- | --- |
| `banking-lab/backend/Banking.api/Features/Ledger/` | Endpoint, guards, policy, service, envelope and postings. Grant/cap/timezone changes are business-rule changes and require tests/plan review. |
| `banking-lab/infrastructure/temporary/AppDbContext.cs` | PostgreSQL mapping and append-only/balanced EF invariants. Do not weaken these to simplify a future feature. |
| `banking-lab/backend/Banking.api/Migrations/20260908124011_AddLedgerAndDevelopmentFunding.cs` | Reviewed forward/Down operations. Never apply Down after funding without a separate recovery plan. |
| `banking-lab/backend/tests/Banking.IntegrationTests/DevelopmentFundingEndpointTests.cs` | Database-free ownership, input, transport, rate, replay, cap and Production-absence coverage. |
| `banking-lab/backend/tests/Banking.IntegrationTests/PostgresLedgerTests.cs` | Guarded real-PostgreSQL upgrade/concurrency/constraint proof. Requires the exact fresh test database. |
| `banking-lab/mobile/banking_mobile/lib/features/development_funding/` | Strict response model, protected repository, same-key controller, and Diagnostics card. |
| `banking-lab/mobile/banking_mobile/lib/features/system_info/presentation/screens/system_info_screen.dart` | Environment/authenticated presentation gate. Backend mapping remains authoritative. |
| `banking-lab/docs/04_Architecture/ledger-development-funding-contract.md` | Current canonical feature contract and rollout state. |

## Normal local commands

Run these from PowerShell. Docker/PostgreSQL and the .NET API use separate terminals.

Start development infrastructure from repository root:

```powershell
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml --profile email up -d postgres mailpit
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml --profile email ps
```

Compose reads the untracked `banking-lab/infrastructure/compose/.env` file. It must contain `POSTGRES_PASSWORD=YOUR_LOCAL_DEVELOPMENT_PASSWORD`; never commit the real value.

Start the API from `banking-lab/backend/Banking.api`:

```powershell
dotnet run --launch-profile http
```

The committed Kestrel configuration keeps the origin on loopback. The phone must use the configured trusted HTTPS proxy URL, never `http://PC-IP:5255`.

Start Flutter from `banking-lab/mobile/banking_mobile` using the currently approved HTTPS URL:

```powershell
flutter run --dart-define=API_BASE_URL=https://YOUR-APPROVED-HTTPS-HOST
```

The exact personal hostname belongs only in the command/local configuration; do not commit it.

## Verification commands

Backend database-free suite from `banking-lab/backend`:

```powershell
Remove-Item Env:BANKING_LEDGER_TEST_DATABASE -ErrorAction SilentlyContinue
dotnet test Banking.slnx --no-restore
```

Flutter from `banking-lab/mobile/banking_mobile`:

```powershell
flutter analyze
flutter test --reporter compact
```

The guarded PostgreSQL test accepts only loopback plus database name `banking_lab_ledger_test`, with no custom search path. Set the connection string only in the current process and do not paste real credentials into source/history:

```powershell
$env:BANKING_LEDGER_TEST_DATABASE = 'Host=127.0.0.1;Port=5432;Database=banking_lab_ledger_test;Username=banking_app;Password=YOUR_LOCAL_TEST_PASSWORD'
dotnet test tests/Banking.IntegrationTests/Banking.IntegrationTests.csproj --no-restore --filter 'FullyQualifiedName~PostgresLedgerTests'
Remove-Item Env:BANKING_LEDGER_TEST_DATABASE
```

The fixture refuses an already migrated database and never resets/drops one. Repeating a fresh-upgrade run requires a separately authorized cleanup/recreation of that exact disposable target.

## Verified results

| Check | Result |
| --- | --- |
| .NET build | Passed, zero warnings/errors before migration generation |
| Backend ordinary suite | 211 passed, 0 failed, 14 opt-in PostgreSQL tests skipped |
| New database-free funding/policy tests | Passed, including Production 404, replay, cap, owner, Manila boundary, input/transport/auth |
| Fresh `banking_lab_ledger_test` run | 4 passed: upgrade preservation, same-key concurrency, distinct-key cap, constraints/reconciliation |
| Flutter analysis | No issues |
| Flutter complete suite | 177 passed |
| Flutter funding-specific tests | 6 passed: strict data/transport/errors plus UUID reuse and rapid-tap single-flight |
| Main app visibility journey | Signed-out Development hides funding; signed-in Development shows disclosure/confirmation at 320 px and 200% text |
| Shared `banking_lab` rollout | Exact migration applied after verified backup; 4 users, 25 sessions, 52 refresh-token rows and 2 zero-balance accounts initially preserved |
| Authenticated funding | Two separately confirmed grants about 59 seconds apart produced 2 transactions, 4 balanced postings and PHP 100,000 on one account; the other account remained zero |
| Non-zero Home regression | Flutter's stale zero-only parser was corrected; focused account tests and the complete 177-test suite pass with clean analysis |
| Final physical verification | Chris confirmed the corrected Home balance and funding behavior; Gio independently verified the second-customer flow |
| Final shared reconciliation | 4 funding transactions, 8 postings, PHP 200,000 total across two accounts, and a zero posting sum |

The first disposable run had one test-order assertion that expected the entire shared fixture to remain empty while other tests had already created isolated customer transactions. The implementation passed; the assertion was narrowed to the pre-existing upgrade account/user, the exact disposable test database was explicitly verified, dropped, recreated, and the corrected 4/4 run passed. Only `banking_lab_ledger_test` was reset; shared `banking_lab` was untouched.

## Migration safety review and shared rollout

Risk was classified **medium** because the migration enables durable monetary state and introduces foreign keys/index creation. Forward operations are additive except replacing `BalanceMinor = 0` with `BalanceMinor >= 0`. Generated SQL contains no data rewrite, seed, grant, account opening, `DELETE`, or table/column drop. Existing zero balances satisfy the new check.

Chris explicitly approved the shared rollout on 2026-09-09. Preflight confirmed PostgreSQL 17.11, no other database connection, no API listener, 4 users, 25 sessions, 52 refresh-token rows, 2 accounts, total balance zero, and migrations through `20260906042449_AddCustomerAccounts` only.

Custom-format backup `banking-lab/.local/backups/banking_lab_pre_AddLedgerAndDevelopmentFunding_20260908T161720Z.dump` is 33,338 bytes with SHA-256 `879ec8048ae100a41d5eb69ad92d6c17adebc57f137a375f0df871a944861d38`. `pg_restore --list` read 81 entries, contained CustomerAccounts, and correctly contained no ledger table.

Only `20260908124011_AddLedgerAndDevelopmentFunding` was applied. Post-check preserved every preflight count and zero total balance, found empty ledger tables, the exact migration marker once, all 10 expected check constraints, all 4 expected indexes, and no EF model drift. After restart, private HTTPS health passed; an unauthenticated funding request returned 401 with `no-store` and wrote no rows.

Application rollback should keep the additive tables. Down drops journal history and may fail when balances are nonzero; it is not the normal rollback path.

## Scoped security review

Reviewed server environment mapping, bearer/session reuse, ownership derivation, HTTPS/forwarding, no-store, body/query/content-type/stream limits, rate policy, idempotency secrecy, fixed money values, checked arithmetic, row locking, exception/log shapes, EF append-only invariants, PostgreSQL constraints, Flutter redirect/origin policy, token refresh, stale-session suppression, response parsing, rapid taps, and uncertain retries.

No unresolved high/critical finding was found in this Slice 4 source/test scope. This is not a full repository penetration test, production readiness claim, or ZAP result.

## Phone checklist after shared rollout

For a fresh account/day, the complete physical checklist is:

1. Sign in and ensure an account is opened.
2. Open **API diagnostics** and confirm **Environment: Development**.
3. Confirm the funding card clearly says fake/test money and PHP 50,000 / PHP 100,000 daily.
4. Cancel once and verify no balance change.
5. Confirm once; verify one success and Home refreshes to PHP 50,000.
6. Tap rapidly during the next request; verify only one additional PHP 50,000 grant.
7. Attempt a third new grant; verify a safe daily-limit message and PHP 100,000 remains.
8. Force a brief network uncertainty only if deliberately planned; Retry must reconcile with the same key, not duplicate funds.
9. Check Light/Dark, 200% text, scrolling, focus, and TalkBack wording/order.
10. Repeat on Gio's separately authenticated account and verify neither customer sees or changes the other's account.

During the first shared test, Chris confirmed the funding action twice after the first request had completed. Both confirmations therefore received different UUID keys and correctly created the two grants allowed by policy; this was not a same-request duplicate. Home initially rejected the valid non-zero account response because `AccountSummary.fromJson` still enforced the earlier zero-only contract. The parser now accepts canonical non-negative signed-64-bit integer strings and formats the result as `PHP 100,000.00`; negative, decimal, signed, leading-zero, and overflow inputs still fail closed. Chris then physically confirmed the corrected Home state, and Gio independently completed the second-customer verification. The final read-only shared reconciliation found four funding transactions, eight postings, PHP 200,000 total across both accounts, and a zero posting sum.

## Deferred follow-ups

- Slice 5 internal transfer endpoint/ledger policy, then its Flutter flow and Activity/receipts in later slices.
- PIN/biometric app lock for restored sessions.
- React administrator/headquarters prototype and WebAuthn/passkey design.
- A separate Cloudflare Tunnel evaluation versus Tailscale Serve, including origin trust, Access policy, DNS, secrets, logs, failure mode, and rollback. No tunnel change is part of Slice 4.
