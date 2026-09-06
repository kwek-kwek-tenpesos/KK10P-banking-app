# Implementation Plan: Customer Accounts and Balances

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Explicitly approved for implementation on 2026-09-06. Use task.md for current delivery evidence and outstanding gates.
- Scope Mode: Approved new feature. Database execution and ZAP require separate approval.
- Execution tracking: [active task](../01_Tracking/task.md). Update this plan in place before approval; use task.md for execution afterward.
- Skill route: acceptance-criteria, supported by migration-safety-review; repository inspection precedes design, implementation follows plan approval, migration execution has its own target-specific gate.

## 1. Goal and confirmed scope

A confirmed, enabled customer with a valid session can explicitly open one PHP simulator account, then see its persisted zero balance on Home. Both existing and newly registered customers use the same flow. This replaces the accounts placeholder with a working API/database/mobile journey.

Chris selected accounts/balances planning while ZAP remains unapproved, and confirmed:

- One PHP simulator account per customer.
- An explicit **Open account** action, starting at **PHP 0.00**.
- Funding and transfers planned separately.

This slice excludes automatic opening during registration/login, seed balances, deposits, withdrawals, transfers, ledger postings, transaction history, holds/available-balance calculations, multiple accounts/currencies, admin tools, public deployment and paid services. Account closure and real-world account numbers are also deferred. The displayed UUID is only a simulator account reference.

The implementation choices below were approved on 2026-09-06. Exact disposable/shared database targets and runtime operations must be confirmed before migration or live verification.

## 2. Repository evidence and affected areas

| Current evidence | Planned consequence |
| --- | --- |
| `banking-lab/mobile/banking_mobile/lib/features/home/presentation/screens/customer_home_screen.dart` contains a protected placeholder | Replace its card with loading, unopened, opening, balance and recoverable-error states; preserve greeting, diagnostics and logout. |
| `banking-lab/infrastructure/temporary/AppDbContext.cs` models identity, refresh tokens, sessions and setup probes | Add a separate customer-account entity/table; preserve the existing context location and authentication tables. |
| `banking-lab/backend/Banking.api/Features/Authentication/SessionBearerEvents.cs` validates persisted sessions and places the current ApplicationUser in HttpContext.Items | Reuse this authorization boundary and derive account ownership exclusively from the validated user. |
| `AuthenticationRequestGuards.cs` and the no-store middleware currently target `/api/v1/auth` | Add narrowly scoped accounts guards before bearer processing; do not assume authentication guards cover the new routes. |
| Mobile `authentication_repository.dart` already exposes `getValidAccessToken`, refresh deduplication and local-session clearing | Reuse these mechanisms; add only the session invalidation/generation handling needed for protected account requests and late-response safety. |
| Existing backend fixtures include database-free tests and explicitly guarded PostgreSQL tests | Use both; in-memory tests cannot establish PostgreSQL uniqueness or concurrent-insert behavior. |

The [authentication contract](../04_Architecture/customer-authentication-contract.md) remains authoritative for session policy. The approved KK10P Bank palette and accessible Material controls remain the visual baseline. No new UI library, font or image asset is needed.

## 3. Proposed API and data contract

### API

| Method and route | Request | Success | Expected failures |
| --- | --- | --- | --- |
| `GET /api/v1/accounts/me` | Bearer token; no body or query parameters | `200` AccountSummary | `404` with Problem Details extension `code: account_not_opened`; common failures below |
| `PUT /api/v1/accounts/me` | Bearer token; JSON `{}` only | `201` for first creation with `Location: /api/v1/accounts/me`; `200` with the same persisted account on repetition | `400` malformed/unknown fields; `415` unsupported content type; common failures below |

Common failures: `400` unsupported query/input or insecure HTTP, `401` missing/invalid/revoked/expired session or ineligible customer, `413` oversized body, `429` request limit, `503` recognized session/database unavailability. Unexpected defects remain server errors and are not disguised as an empty account or successful opening. JSON errors use the existing Problem Details conventions.

`AccountSummary` fields: `id` (UUID string), `currency` (`PHP`), `balanceMinor` (base-10 integer string, initially `"0"`), `openedAtUtc` (UTC ISO-8601 string). No owner ID, email, credentials, private metadata or ORM entity is serialized. An integer string preserves money precision across clients; Dart parses with BigInt and formats minor units without floating-point arithmetic.

Every account response, including rejection, has `Cache-Control: no-store`. Enforce HTTPS before bearer validation using existing trusted-loopback forwarding; plain HTTP receives an error rather than a redirect. The mobile service rejects a non-HTTPS API origin before attaching a token and disables redirects on authenticated account calls. The diagnostic GET and ZAP scope remain unchanged.

Proposed local-prototype request budget: a named accounts policy allowing 30 requests/minute per direct/trusted-proxy IP, no queue, with the existing 429/Retry-After behavior. Both account methods count toward it. It remains a per-process development limiter, with independent authentication policy limits. Bound request bodies at 16 KiB, including chunked input; reject unexpected bodies/fields and query parameters. No caller-supplied ownership or balance field is accepted.

### Database

Add `CustomerAccounts` with:

| Column | Type and invariant |
| --- | --- |
| `Id` | UUID primary key, generated by the backend on first opening |
| `UserId` | Required string matching the existing identity key; unique index; foreign key to `AspNetUsers.Id`, delete restricted |
| `Currency` | Required three-character value with a `PHP` check constraint |
| `BalanceMinor` | Required bigint, default 0, with a **balance equals zero** check constraint for this slice |
| `OpenedAtUtc` | Required UTC timestamp, assigned by the backend |

The unique owner index enforces one account under concurrent requests and supports the only account lookup. No table scan of other customers is needed. Opening is one atomic insert; retries must not reset the original ID, timestamp or balance. Catch only the named owner-uniqueness violation for the expected race, discard the failed inserted entity, and read the winning row using a clean tracking/transaction state. Other database errors must not masquerade as duplicate success.

The balance is persisted and read from PostgreSQL. Zero is the only supported monetary state: no funds have been issued and no balance-write API exists. This is not a completed ledger foundation. A future funding/transfer plan must define the authoritative ledger, postings, reconciliation and concurrency model before relaxing the zero-only constraint or permitting nonzero values. UI text must say **Simulator funds** and explain that funding arrives in a later slice.

## 4. Planned files

Paths below are repository-relative; new files are proposed, not existing deliverables.

| Files | Responsibility |
| --- | --- |
| Add `banking-lab/backend/Banking.api/Features/Accounts/CustomerAccount.cs`, `CustomerAccountContracts.cs`, `CustomerAccountService.cs`, `CustomerAccountEndpoints.cs`, `AccountRequestGuards.cs` | Entity, strict empty opening request/summary DTO, owner-scoped retrieval/idempotent opening, route mapping and scoped transport/body/cache guards. |
| Modify `banking-lab/backend/Banking.api/Program.cs` | Register/map accounts services, guards and rate policy using the existing pipeline; keep authentication and diagnostics behavior. |
| Modify `banking-lab/infrastructure/temporary/AppDbContext.cs` | Add DbSet and exact account constraints; do not relocate or broadly refactor this context. |
| Add a timestamped `AddCustomerAccounts` migration and designer under `banking-lab/backend/Banking.api/Migrations/`; modify `AppDbContextModelSnapshot.cs` | Add only the accounts table/index/constraints; no backfill, seeds or authentication-table changes. Generate and review after implementation approval; leave unapplied pending target approval. |
| Add files under `banking-lab/mobile/banking_mobile/lib/features/accounts/data/{models,services,repositories}/` and `presentation/{controllers,widgets}/` | Account summary parsing/formatting, authenticated requests, typed unopened state, session-scoped state and account card. Follow current feature folder patterns. |
| Modify `banking-lab/mobile/banking_mobile/lib/features/home/presentation/screens/customer_home_screen.dart` | Integrate account card and explicit opening/retry/refresh controls. |
| Modify mobile `features/authentication/data/repositories/authentication_repository.dart` and `features/authentication/presentation/controllers/authentication_controller.dart` | Narrow session-generation/invalidation integration so logout, a new login or final 401 invalidates pending work and stale credentials/results cannot reappear. Preserve secure storage, refresh deduplication and session deadlines. |
| Modify mobile `core/errors/app_failure.dart` only if needed for secure-connection wording | Make the existing HTTPS error suitable for account access; preserve other error mappings and keep account-not-opened mapping feature-local. |
| Add account endpoint/model/PostgreSQL tests under `banking-lab/backend/tests/Banking.IntegrationTests/`; add mobile tests under `banking-lab/mobile/banking_mobile/test/features/accounts/` | Contract, owner isolation, races, migration preservation, parsing and UI/state verification. Extend existing home/auth tests for affected behavior. |
| Add `banking-lab/docs/04_Architecture/customer-accounts-contract.md` and `banking-lab/docs/03_Walkthroughs/walkthrough-accounts-and-balances.md` on delivery | Record implemented contract, learning concepts, exact paths and truthful automated/manual results. |
| Update authentication contract's home description, `README.md`, active task and top of `CHANGELOG.md` on delivery | Link the accounts contract, replace stale milestone statements and record one completed behavior entry. Archive this task only when the slice is verified complete. |

## 5. Plain-language implementation sequence

```text
1. After plan approval, copy accepted scope, invariants and execution steps into task.md.
   Preserve unrelated working-tree edits; perform no Git write commands.
2. Add the account model, constraints and strict request/response shapes.
   Generate the additive migration and review its SQL without applying it.
3. For every account request:
   set no-store; enforce HTTPS and bounded input; apply the accounts request limit;
   run existing bearer/session/customer validation;
   obtain the validated customer from the server context, never the request.
4. For GET:
   read only the account whose UserId equals that customer;
   if absent, return the explicit account_not_opened response;
   otherwise return the minimal summary without writing anything.
5. For PUT:
   accept only the empty request contract;
   read this customer's account; if present, return it unchanged;
   otherwise insert a server-generated account with PHP and zero balance;
   if the named unique-owner constraint races, read and return the winner;
   return 201 only for a committed new account, otherwise 200 for the existing one.
6. On authenticated Home:
   capture the current session generation and load the account once;
   show a spinner while loading, Open account only for account_not_opened,
   or the returned account reference and formatted balance on success.
7. On Open account:
   disable duplicate taps and send PUT {}; show the persisted summary on success;
   on an uncertain network result, explain that status is unconfirmed and offer Retry;
   Retry reads current state first, then may repeat the idempotent PUT if still absent.
8. Before protected calls, use getValidAccessToken and existing shared refresh logic.
   If the API returns 401, allow at most one refresh and one retry;
   a definitive refresh/retry 401 clears local session state and routes to Login;
   a network/503 failure preserves recoverable credentials and offers explicit Retry.
9. On logout, session invalidation or another login:
   invalidate the session generation and clear account state immediately;
   cancel/discard late account responses and reject stale token acceptance;
   apply the same generation guard to in-flight refresh and secure-storage writes
   so old work cannot restore credentials after logout or overwrite a newer login.
10. Run database-free backend and Flutter checks, including the affected auth regressions.
    After separate disposable-target approval, run PostgreSQL migration/race tests.
11. After reviewed target-specific rollout approval and backup, apply the migration
    to the shared development database and verify the physical-phone journey.
12. Update canonical docs, walkthrough and changelog with actual evidence;
    leave any unexecuted manual/database gates explicitly pending.
```

## 6. Pass/fail acceptance criteria

- [ ] A valid customer with no account sees an unopened state; GET does not create records, and signup/login behavior is unchanged.
- [ ] Open account persists exactly one PHP account at zero; app restart and subsequent sign-in return the same account ID/opening time/balance.
- [ ] Repeated, simultaneous and timeout-retried PUTs return one persisted account; no duplicate rows or reset values occur.
- [ ] Customer A can only retrieve/open A's account; B receives B's own account/unopened result. Forged owner/balance fields and unsupported queries are rejected without data disclosure or writes.
- [ ] Missing, forged, revoked, expired, locked, disabled and unconfirmed identities cannot read/open accounts; database failures return a recoverable service failure rather than zero or unopened success.
- [ ] HTTPS is enforced, authenticated requests do not follow redirects, no-store covers success/errors, and body/request limits hold. No credentials or complete response bodies are logged.
- [ ] Migration creates only the intended table/index/constraints, preserves existing identities and sessions, rejects duplicate owners/orphans/non-PHP/nonzero balances and does not cascade-delete accounts.
- [ ] UI distinguishes loading, unopened, opening, loaded zero, offline/timeout, invalid-response, rate-limited and service-unavailable states; only the specific account_not_opened code enables opening.
- [ ] The displayed balance comes from the API; amount parsing rejects malformed/unsupported values and uses integer arithmetic. No transaction list, sample balance, funding or transfer control suggests unavailable behavior.
- [ ] Logout/user switching clears account data immediately. Delayed requests/refreshes cannot restore old account data, old credentials or another customer's session.
- [ ] Account UI fits 320/360/412 logical-pixel phone widths and a 768-wide layout, including 200% text scaling, without overflow; controls have visible focus/contrast, at least 48 logical-pixel touch targets and useful TalkBack labels.
- [ ] Existing auth/diagnostics regression checks pass; PostgreSQL results and physical-phone results are recorded separately, with skips never reported as passes.

## 7. Verification and manual procedure

Commands below are planned checks after implementation, not results from this planning turn. From the repository root, run database-free backend tests with `BANKING_AUTH_TEST_DATABASE` unset in that test process:

```powershell
dotnet test banking-lab/backend/tests/Banking.IntegrationTests/Banking.IntegrationTests.csproj --no-restore --verbosity quiet
```

From `banking-lab/mobile/banking_mobile`, run `flutter analyze` and `flutter test`. Check targeted formatting without rewriting unrelated files. Test request serialization/status codes, exact amount formatting, final-401 invalidation, a shared refresh for simultaneous requests, recoverable outages, repeated taps, delayed response after logout and delayed refresh during user switching. Test account transport/cache/body/limit rejection with the existing test host; exercise real session validation for ownership cases.

Add PostgreSQL tests behind an explicit disposable-database guard. Reuse the existing guard approach without weakening target validation or silently using shared configuration. Test concurrent inserts with separate DbContexts, constraint violations and upgrade from the current latest migration while preserving seeded fake identities/sessions. Any test fixture that applies migrations or resets a database requires exact target approval first. Inspect existing fixture setup before broadening its migration assumptions. This plan authorizes no fixture execution against a database.

Manual checks after runtime/rollout approval:

1. Start the approved local services and trusted HTTPS path. Sign in as fake customer A on the physical Android phone. Confirm unopened state and simulator wording.
2. Tap Open account; confirm PHP 0.00 and an account reference. Repeat/retry opening through the approved local test flow; verify one row and unchanged reference.
3. Restart the app; confirm session restoration and the same account. Refresh with connectivity disabled; confirm a recoverable error, not invented balance or unopened state. Restore connectivity and Retry.
4. Sign out during a delayed account response, then sign in as fake customer B. Confirm no A data flashes and B starts unopened. Open B's account and confirm a different reference.
5. Exercise invalid-session and dependency-failure cases in the isolated environment. Confirm sign-in routing for definitive rejection and retry for outages.
6. Check narrow/wide layouts, 200% text, TalkBack labels/focus and touch targets. Record device and observed results; do not infer phone checks from widget tests.

## 8. Preliminary migration safety review and recovery

- Risk: medium for rollout, despite an additive table, because the new relationship touches identity ownership and creates durable customer records. This is a design review; no generated migration/SQL has yet been examined.
- Forward changes: new table, unique owner index, foreign key and value constraints only. No planned drop, rename, data rewrite, backfill or seed grant. Existing customers intentionally remain unopened.
- Compatibility: old application code is expected to tolerate the extra table; new account endpoints require the new schema. Apply the reviewed schema before enabling the new backend/mobile flow. Do not apply migrations automatically at app startup.
- Data/locking: inspect target migration history and conflicting objects without exposing rows/credentials. The new table starts empty; its indexes do not rewrite existing account data, but DDL/FK locks on the identity relationship still require review of actual SQL and target activity.
- Constraints: all new fields are required; unique UserId prevents duplicate opening, restricted deletion protects account records, and PHP/zero checks match this slice. Test the deletion restriction explicitly because it changes what a future identity-deletion operation can do.
- Backup/rollout: identify and approve the exact target, take a verified backup before shared rollout, test on an approved disposable database, review generated SQL and migration order, then seek target-specific execution approval.
- Recovery: prefer reverting application changes while retaining the additive table. A generated Down migration drops customer accounts and is destructive after use; never run it as automatic cleanup. Any schema/data rollback requires separate approval and an assessed backup/restore path.
- Recommendation: suitable to proceed to implementation review; **not approved to apply a migration**. Real SQL review, disposable execution, backup and shared-target approval remain gates.

## 9. Evidence from this planning turn

On 2026-09-06, root AGENTS.md and active handoff were read; current API, session, account-placeholder and data-context code were inspected. No historical archives or draft documents were loaded. Existing unrelated working-tree edits were preserved.

Scanner default preview exited successfully. All 60 offline scanner safety checks passed; no scanner, Docker daemon or API was contacted and no report was generated. ZAP remains unapproved. No account code, migration, service startup, database test or physical-device check ran. This turn changes only this plan and the active task.
