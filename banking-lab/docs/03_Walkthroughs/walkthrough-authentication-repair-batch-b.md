# Authentication Repair: Batch B — Persistent Sessions

> Follow-up: [Batch C review](walkthrough-authentication-repair-batch-c.md) corrected expiry during refresh persistence and completed scanner-wrapper/artifact hygiene. Test totals and outstanding-next-batch statements below describe the batch B delivery.

- Date: 2026-09-04
- Audience: Chris and Gio; learning, code review and prototype operation.
- Status: Implemented and verified against the explicitly authorized disposable database. Shared-database rollout, phone HTTPS checks and batch C are not completed.
- Verification: 166 backend tests passed, zero failed/skipped, including six PostgreSQL cases. Chris supplied a screenshot confirming clean Flutter analysis and 59 passing mobile tests after the batch A lint fix; no mobile code changed in batch B.

## What now works

Each successful login creates a separate session. Access JWTs carry its `sid` identifier. The API checks the stored session and current user before serving protected endpoints; a valid JWT signature alone is no longer sufficient.

| Rule | Enforcement |
| --- | --- |
| Access lifetime | At most 10 minutes, capped by the session deadline |
| Inactivity | 15 days since login or last successful refresh |
| Absolute lifetime | 90 days from original login; refresh never resets this |
| Refresh budget | 30 successful rotations per session per one-minute window, persisted with rotation; additional attempts return 429/Retry-After |
| Logout | Revokes the entire session, including descendants of an older rotated token; unrelated logins remain active |
| Replay | A consumed token terminates its own session family, not every session belonging to the user |
| Eligibility | Disabled, unconfirmed, locked-out or security-stamp-changed users cannot refresh or access protected endpoints |

Here, activity means successful login/refresh, not a UI tap or an arbitrary GET. The future mobile session client must refresh during legitimate use and must not renew indefinitely in the background merely to keep an idle session alive. This batch does not implement single-device account binding, admin recovery, email delivery, a mobile login screen or a device-attestation system.

## Sequential logic

```text
Login: verify user -> create session + hashed refresh token -> commit -> return JWT with sid
Refresh: load token + session -> check deadlines/user -> advance idle deadline, not absolute
         -> compare session Version + consume token + insert replacement in one transaction
Conflict/replay: reload current session -> persist family revocation -> return generic failure
Protected GET: verify JWT -> check sid ownership, session deadlines and current user -> allow
Logout: find session using refresh token (even an ancestor) -> revoke family -> 204 or safe 503
```

Clients must serialize refresh calls. Two simultaneous uses of one token cannot be reliably distinguished from token theft: at most one rotation commits, then the conflicting request revokes that family. Consequently even a 200 response from the winning request may already be unusable after the conflict. A lost refresh response can also require a fresh login; no replay grace window is implemented.

## Concepts to learn

- **Session family:** All tokens descended from one login share one session ID. It provides a precise target for logout and replay handling.
- **Optimistic concurrency:** A `Version` value proves that the session has not changed since it was read. EF includes it in the update condition; a competing update causes a concurrency failure instead of overwriting newer state. See [EF concurrency](https://learn.microsoft.com/en-us/ef/core/saving/concurrency).
- **Transaction:** Updating the session, consuming the old token and inserting its replacement either commit together or roll back together. The PostgreSQL failure test verifies this rather than relying on EF InMemory. See [EF transactions](https://learn.microsoft.com/en-us/ef/core/saving/transactions).
- **Security stamp:** Identity's credential-state marker is captured at login and checked later. Changing it invalidates older sessions without embedding it in the JWT.
- **Fail closed:** If the database cannot validate a protected request, access is denied with a safe 503; it does not silently accept the signed token.

## Files and responsibilities

Repository-relative paths:

- `banking-lab/backend/Banking.api/Features/Authentication/CustomerSession.cs`: persisted identity, deadlines, revocation, refresh budget and concurrency version.
- `banking-lab/backend/Banking.api/Features/Authentication/CustomerSessionService.cs`: refresh and family logout/replay logic; bounded concurrency retries.
- `banking-lab/backend/Banking.api/Features/Authentication/SessionBearerEvents.cs`: session/user checks after cryptographic JWT validation; safe challenge responses and request-scoped verified user.
- `banking-lab/backend/Banking.api/Features/Authentication/AuthenticationDependencyFailure.cs`: narrowly recognizes database errors, including Npgsql-wrapped transient errors, without hiding unrelated programming errors.
- `CustomerLoginService.cs`, `CustomerRefreshToken.cs`, `CustomerLoginContracts.cs`, `TokenService.cs`, `ITokenService.cs` in that same folder: login creates a family, refresh rows link to it, rate-limit outcome, and session-bound JWT issuance.
- `banking-lab/backend/Banking.api/Program.cs`: service/event wiring and protected `GET /api/v1/auth/me`.
- `banking-lab/infrastructure/temporary/AppDbContext.cs`: mappings, restrictive foreign keys and session concurrency token.
- `banking-lab/backend/Banking.api/Migrations/20260904152654_AddCustomerSessions.cs`, its `.Designer.cs`, and `AppDbContextModelSnapshot.cs`: generated additive schema update and matching snapshot.
- `banking-lab/backend/tests/Banking.IntegrationTests/CustomerSessionTests.cs`: expiry, ownership, eligibility, JWT rejection, budget, replay/logout and minimal profile tests.
- `banking-lab/backend/tests/Banking.IntegrationTests/PostgresSessionTests.cs`: guarded opt-in database fixture, migration upgrade, synchronized races, rollback, rate budget and wrapped-read-failure tests.
- `AppDbContextModelTests.cs` and `TokenServiceTests.cs` in the test folder: updated mapping and `sid` expectations.
- `README.md`, `CHANGELOG.md`, tracking and batch A/B walkthroughs: updated status, canonical session behavior and operational boundaries.

No dependencies, mobile source, Tailscale settings, appsettings, shared database data or scanner scripts were changed by this batch. No Git staging, commits, pushes or branch operations were performed.

## API contract

- `GET /api/v1/auth/me` requires HTTPS and a session-valid Bearer token. Success is 200 with only `{ "id": "...", "displayName": "..." }`; displayName may be null. Missing/invalid/revoked/expired credentials return 401; a session-store failure returns 503. Responses use no-store.
- Login/refresh keep the existing successful response fields. Refresh additionally enforces the persisted 30/minute session budget with 429 and Retry-After, alongside batch A's process-local 60/minute/IP limit.
- Logout accepts a refresh-token body, including a rotated ancestor, and returns 204 after revocation or for an unknown well-formed token. Persistence failure remains 503.
- Pre-session refresh rows with null `SessionId`, and old JWTs without `sid`, cannot authenticate after rollout. Users must sign in again. No fabricated historical session origins are backfilled.
- The original batch A private signing-key and trusted HTTPS requirements still apply. Registration delivery remains unconfigured and returns 503 by default; test-only confirmed identities are not a shipped verification bypass.

## Migration safety review

Risk: **high for authentication compatibility**, although the upgrade schema operations are additive. `Up` adds nullable `CustomerRefreshTokens.SessionId`, creates `CustomerSessions`, indexes session/user lookup paths and adds restrictive foreign keys. No existing column/table drops, row deletes, token rewrites, or cascade-delete expansion occur in `Up`. Existing null session links satisfy the new FK. `Version` is an application-managed concurrency token, not a PostgreSQL generated value.

The new application requires the new schema. Old application instances must not remain active during rollout: they can still issue sessionless tokens. Stop the API, take and verify a backup of any shared database, review the exact migration target, apply the additive migration, then deploy only the new API and require fresh login. Index creation and FK validation can lock existing tables; plan a maintenance window for larger datasets. New restrictive FKs also mean future account/session deletion must be designed explicitly.

`Down` drops the session table and link column: it loses session history and is **not a safe operational rollback**. It was reviewed, not executed. Prefer a forward fix; do not roll back to code that accepts revoked legacy credentials. Shared-database backups/rollout remain pending.

Actual application: only `banking_lab_auth_repair_test` in `compose-postgres-1`, created empty with Chris's permission. The fixture first migrated to the prior refresh-token schema, inserted a fake legacy user/token, then applied the session migration. The preservation test confirmed the old row/user survive and the old token is denied. On repeated runs the fixture only applies pending migrations; it never downgrades, drops, or recreates the database. Synthetic rows accumulate. The database is retained for inspection; no cleanup was performed.

## Tests and reproducible commands

From the repository root, ordinary database-free testing:

```powershell
dotnet test banking-lab/backend/tests/Banking.IntegrationTests/Banking.IntegrationTests.csproj --no-restore --verbosity quiet
```

Without `BANKING_AUTH_TEST_DATABASE`, the six PostgreSQL cases explicitly skip; do not report those as passed. A final database-free rerun (`--no-build --no-restore --verbosity quiet`) confirmed **160 passed, 6 skipped, 0 failed**. For the live tests, privately configure that environment variable with the authorized local disposable database connection string, then use the same command. The fixture rejects any database name except `banking_lab_auth_repair_test` and any host except `localhost`/`127.0.0.1`. Do not paste real connection strings into chat or tracked files. No default connection fallback or paid service is used. Database test setup applies pending migrations and inserts synthetic data, so it is not read-only.

Actual final full run with the disposable connection configured: **166 passed, 0 failed, 0 skipped**. The six PostgreSQL checks cover legacy upgrade preservation, synchronized refresh/refresh, synchronized logout/refresh, unique-index rollback, 30 successive rotations sharing one budget, and fail-closed recovery from a wrapped database timeout. Barriers synchronize competing writes rather than hoping requests overlap by chance.

Earlier failures were corrected: model FK expectations needed the new session relationship; the test fixture needed normalized usernames; and the real PostgreSQL timeout test exposed Npgsql's transient-error wrapper. One overlapping local build caused temporary MSB3026 copy retries; the final run was serialized and completed without those warnings. No ZAP scanner ran.

## Review, customization and remaining work

Code review covered session ownership, protected endpoint enforcement, no secret-bearing logs/responses, deadline boundaries, bounded concurrency handling, additive migration/rollback risks and transaction tests. Automated checks do not certify production banking security.

Keep policy changes in `JwtOptions` plus its validator and matching tests. Never remove server-side session checks or add a development bypass for real accounts. Future protected endpoints must call `RequireAuthorization` and add resource ownership checks. Revocation is checked at authentication time; it does not cancel an already-authorized in-flight request. Money-changing operations will need their own transaction/authorization design.

Next: batch C's scanner safety/artifact hygiene, followed by a separately reviewed shared-database rollout and trusted phone HTTPS verification. Email verification delivery and mobile login/session integration remain necessary before claiming a working end-to-end signup/login journey. Session-history retention/cleanup and security-event observability need later operational work; no automatic session deletion job is added here.

## Shared database rollout addendum — 2026-09-05

Chris started the existing PostgreSQL 17 container and authorized the exact shared rollout. Read-only preflight identified `compose-postgres-1` and database `banking_lab`; EF history contained the Identity and refresh-token migrations, while only `20260904152654_AddCustomerSessions` was pending. The database was approximately 8 MB with zero users and zero refresh-token rows. `CustomerSessions` and `CustomerRefreshTokens.SessionId` did not already exist.

Before migration, a PostgreSQL custom-format dump was created under Git-ignored `banking-lab/.local/backups/`. Its SHA-256 was recorded locally and `pg_restore --list` successfully read the archive catalog. EF reported no model changes after the migration snapshot. The command targeted the named session migration rather than applying an unknown latest migration.

Application completed successfully. Post-checks confirmed the migration-history entry, the new `CustomerSessions` table, nullable `CustomerRefreshTokens.SessionId`, both session indexes and both restrictive foreign keys. Users, refresh tokens and sessions remained at zero rows. No `Down` migration, data deletion, container rebuild, Tailscale change, scanner or Git operation occurred.

Migration assessment after rollout: the additive schema operation was low locking risk on this empty local database but remained medium operational risk because it changes authentication compatibility. The verified backup is the recovery point; prefer a reviewed forward fix instead of `Down`, which would delete session data. Runtime JWT signing, trusted HTTPS, real verification delivery and mobile session integration are still required. Tailscale reported `NoState` during the follow-up check, so no Serve configuration or phone test was attempted.

## End-to-End Follow-up — 2026-09-05

The private local JWT setting, SMTP verification adapter, confirm/resend endpoints and Flutter session client are now implemented and locally verified. The statement immediately above remains the historical rollout status; use the [current authentication contract](../04_Architecture/customer-authentication-contract.md) and [end-to-end delivery walkthrough](walkthrough-end-to-end-customer-authentication.md) for current behavior and results. Tailscale still reported `NoState`, so trusted physical-phone HTTPS remains the only authentication-slice verification blocker.
