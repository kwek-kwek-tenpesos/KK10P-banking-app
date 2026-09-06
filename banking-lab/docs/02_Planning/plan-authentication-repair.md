# Implementation Plan: Authentication Repair and Documentation Alignment

- Date: 2026-09-04
- Status: Approved by Chris on 2026-09-04; implementation in progress
- Scope: Repair the existing customer authentication foundation before new banking features or scanning.
- Authorization received: Chris approved implementation, changing inactivity to 15 days and retaining the 90-day absolute limit. Database application, isolated database setup, scanner execution/downloads and infrastructure choices remain separately gated.
- Execution tracking: [task.md](../01_Tracking/task.md). After approval, track work there rather than repeatedly rereading this plan.

## 1. Goal and boundaries

Keep ASP.NET Identity, EF Core/PostgreSQL, Flutter/Riverpod/Dio, and the existing secure refresh-token store. Do not rewrite the app. Preserve System Info, Tailscale/network settings, existing user edits, fake-money-only scope, and no-paid-service delivery.

No Git staging, commits, pushes, branch switching, visibility changes, license changes, cache deletion, shared-database migrations, scanner execution, or downloads are authorized by this document. Ask before an isolated PostgreSQL test database is created or changed. Do not read draft contents as requirements.

Email delivery, verification/resend endpoints, mobile login/session integration, accounts, transfers, history, and neumorphic UI remain subsequent feature slices. Registration must stay fail-closed until verification is actually implemented; do not bypass confirmation or seed a usable account to make a demo appear complete. Admin recovery/passkeys and Bluetooth remain later work; AI guards remain concept-only.

## 2. Evidence and correction targets

| Finding in the reviewed implementation | Repair target |
| --- | --- |
| JwtOptions has a source-known signing-key fallback | Fail startup for missing/invalid signing configuration; test-only fixtures inject their own keys |
| Login and refresh omit EmailConfirmed | Require current confirmed, enabled, permitted user state before issuing credentials |
| Rotation reads then updates without a concurrency guard | Serialize/conditionally consume the token in PostgreSQL; never commit two valid successors |
| Logout endpoint ignores a false service result | Return safe 503 on persistence failure; do not promise server logout |
| Revocation operates by user, with no persisted session family | Independently revocable sessions and immediate eligibility checks on protected requests |
| Mobile advertises 12 characters; server requires 15 Unicode code points | Align UI guidance, bounds, tests, and documented normalization behavior |
| Refresh expiry is hardcoded; access response says 900 seconds | One validated policy and accurate response lifetimes |
| Auth routes lack request throttling and HTTPS enforcement | Bound requests, rate-limit before expensive work, and prohibit cleartext credential exchanges |
| ZAP plan says passive; script defaults to active and accepts arbitrary targets | Safe-mode command, explicit local scope, disposable test environment, separate execution approval |

## 3. Approved policy reconciliation

Restore the earlier [customer baseline](../01_Tracking/BL-LEARN-001_Development_Fundamentals_and_Current_Setup.md#approved-first-version-choices), with Chris's explicit 15-day inactivity amendment below. This policy supersedes the conflicting initial slice-3 plan:

- Access token: at most 10 minutes, capped by the remaining session deadline.
- Session inactivity: 15 days from login or last successful refresh.
- Absolute session expiry: 90 days from login, never extended by refresh.
- Five consecutive wrong passwords: five-minute lockout. Unknown, disabled, unconfirmed, locked, and wrong-password login outcomes share generic 401 responses. Timing mitigation is not a constant-time guarantee.
- Independent customer sessions, not permanent device binding. Reuse/logout revokes the relevant session family, not unrelated customer devices.
- JWT identifiers/timestamps only, including a server-issued session ID; no email/profile claims. Validate signature, explicit allowed algorithm, issuer, audience, expiry and persisted session/current user eligibility.
- Passwords: backend-authoritative 15-128 NFC-normalized Unicode code points, preserving case/spaces. Mobile must not advertise a weaker rule or count UTF-16 units as characters. Review NFC support before adding any package; the backend remains authoritative for normalization and blocklist checks.
- Keep the current login/refresh response fields for this repair (`accessToken`, `refreshToken`, `tokenType`, `expiresInSeconds`), with accurate remaining lifetime. The richer profile/expiry response from the old proposal is deferred to mobile session integration and requires explicit contract alignment there.
- Logout target: idempotent 204 after confirmed revocation, including unknown well-formed tokens; malformed input may be 400, persistence failure is 503. Mobile logout is not yet integrated.

Approval is not a statement that code already implements every value. Track verified implementation in task.md; retain earlier policy documents as historical records.

## 4. Ordered implementation batches

### A. Fix existing behavior without applying schema changes

1. Validate Jwt options on startup. Require an externally supplied random signing secret with at least 256 bits of entropy; length checks alone cannot prove entropy. Reject known sample/fallback values and invalid lifetimes. Never print the key. User secrets/environment variables are the setup path, not tracked JSON.
2. Check confirmation, enabled state and lockout consistently; preserve bounded password handling and safe failures. Check Identity write results and map dependency failures safely.
3. Respect logout persistence failure and add regression tests.
4. Align mobile password guidance/Unicode-aware validation and backend field errors. Add boundary tests, including 12-14 characters and supplementary Unicode characters. Preserve existing form and System Info behavior.
5. Add request size/field bounds, `Cache-Control: no-store`, and throttling to existing authentication routes. Use the earlier baseline: login 10/minute/IP, registration 5/15 minutes/IP, refresh 60/minute/IP plus 30/minute/session, logout 60/minute/IP. Session partitioning is completed with batch B. Reject excess work without queuing; emit 429 with Retry-After. Single-instance IP counters reset on restart; document that limitation. Do not trust arbitrary forwarded IP headers.
6. Refuse cleartext credential requests in the Flutter authentication service before sending them; reject HTTP auth requests on the API rather than redirecting a credential body. System Info HTTP/Tailscale diagnostics remain available. In-process test transport must use explicit test-host configuration, not a shipped bypass.
7. Preserve current network configuration. A real phone requires a separately verified trusted HTTPS endpoint/certificate before credential testing; do not disable certificate validation. Ask Chris for the intended local HTTPS host/certificate setup before changing infrastructure.

### B. Repair session persistence and rotation

1. Add a persisted CustomerSession with user ID, creation time, inactivity/absolute deadlines and revocation state. Associate refresh tokens with their session. Generate a new migration; never edit previously applied migration files.
2. Existing tokens have no reliable original family/absolute expiry. Proposed migration policy: preserve users and old rows, invalidate legacy tokens and require fresh login instead of guessing session ownership. This is a security-visible sign-out and must be included in the separate migration approval.
3. Coordinate refresh, replay revocation and logout using a consistent session-first database lock/transaction order. Use row locking or an equivalent checked atomic consumption design; a default SaveChanges transaction alone is insufficient.
4. Generate and persist one successor only after confirming the session/token is still eligible under the lock. Commit before returning credentials. A competing reuse request revokes that family; no replay grace window or ambiguous automatic retry is introduced.
5. Add a session ID claim and validate persisted session/current eligibility on protected authorization. Add the already-proposed GET /api/v1/auth/me as a small protected contract returning only id, email, displayName and emailVerified. No role or banking-resource implementation is included.
6. Review migration SQL and test only against an explicitly authorized disposable PostgreSQL database. Verify simultaneous refresh, refresh/logout races, user isolation, session expiry and dependency failures. InMemory tests do not establish PostgreSQL locking correctness.

### C. Safe scanner preparation and repository hygiene

1. Fix the PowerShell script using a native executable argument array, not Invoke-Expression. Validate the target and imported OpenAPI server destinations against an explicit local allowlist; reject external hosts and unsafe redirects. Probe the selected target, not an unrelated hardcoded URL.
2. Verify CLI flags against the selected ZAP version, use API safe mode (-S), and correct the misleading timeout option/description. Align plan and script ports. Safe mode disables active scanning, but imported API operations may still send state-changing requests: use a disposable database and fake identities even for baseline scans.
3. Keep authentication/authorization, replay, and concurrency assertions in automated tests; a clean header scan does not prove them. Reports must not be published without credential/personal-data review.
4. Add narrowly scoped Git ignores for generated backend/.dotnet cache and local scanner reports; do not delete files or ignore source/tests. Correct the workflow kit location or explicitly document a numbered-folder exception in a separately reviewed rules edit. Preserve the actual repository visibility and license.
5. Scanner image download and execution remain a separate approval gate after repairs and environment review. No automated scan of the shared Chris/Gio database.

## 5. Plain-language pseudocode

```text
START API:
    validate secret and policy; stop with a safe configuration error if invalid

LOGIN:
    enforce HTTPS, bounded input and rate limits
    check credential plus confirmed/enabled/unlocked user
    on any denied eligibility: return the same generic login failure
    create a new session with fixed absolute expiry and inactivity deadline
    save session and random refresh-token HASH
    only after commit: return short-lived JWT and the refresh credential

REFRESH:
    enforce transport, input and rate limits; find token by HASH
    lock owning session, then re-read token and current user state
    if consumed-token replay: revoke this family, commit, reject
    if expired/revoked/ineligible: reject without creating a successor
    consume current token; create one replacement; advance inactivity only
    commit; return credentials capped by the session deadline

PROTECTED REQUEST:
    validate JWT and current session/user; deny if any check fails
    database outage: fail closed with safe dependency error, not fake success

LOGOUT:
    lock and revoke the owning session family; commit
    return 204 only after confirmation, or safe 503 on persistence failure
```

## 6. Primary affected paths

All paths are repository-relative; new file names below are proposed, not existing artifacts.

- `banking-lab/backend/Banking.api/Features/Authentication/`: TokenService, ITokenService, CustomerLoginService, CustomerLoginContracts, CustomerRefreshToken; proposed CustomerSession and session validation support.
- `banking-lab/backend/Banking.api/Program.cs`: options validation, endpoint guards, safe error mapping and protected profile route.
- `banking-lab/infrastructure/temporary/AppDbContext.cs` and `banking-lab/backend/Banking.api/Migrations/`: session mapping and new reviewed migration/snapshot.
- `banking-lab/backend/tests/Banking.IntegrationTests/`: options, eligibility, lockout, session, endpoint, concurrency and failure regression tests.
- `banking-lab/mobile/banking_mobile/lib/features/authentication/` and corresponding `test/features/authentication/`: password policy guidance and credential transport guard.
- `banking-lab/scripts/run-zap-scan.ps1`, `banking-lab/scripts/zap-rules.tsv`, root `.gitignore`: scanner safety and local artifact hygiene, without running or deleting artifacts.
- `README.md`, relevant `docs/02_Planning/` plans, `docs/03_Walkthroughs/` and `docs/01_Tracking/task.md`: actual behavior, approval boundaries and verification records. Add one dated CHANGELOG entry only after code delivery.

## 7. Acceptance and verification gates

- [x] Chris approved the policy reconciliation and implementation batches with 15-day inactivity; no code repair is marked complete by approval alone.
- [ ] Missing/known fallback secret prevents startup; valid test-injected configuration works without printing secrets.
- [ ] Unconfirmed/disabled/locked users cannot login or refresh; login errors do not disclose account status.
- [ ] Logout database failure is 503, not successful logout; repeated confirmed logout is idempotent.
- [ ] Mobile and API password expectations agree; System Info and existing storage regressions pass.
- [ ] Requests are bounded/rate-limited; mobile sends no cleartext credential requests; API auth responses are no-store.
- [ ] Isolated PostgreSQL test setup and migration SQL receive separate explicit approval before use.
- [ ] PostgreSQL races cannot leave two usable successors; logout/reuse affects only the owning session; old JWTs fail subsequent authorization after revocation.
- [ ] Token deadlines and response metadata match the 10-minute/15-day/90-day policy; absolute expiry cannot slide.
- [ ] Existing and new automated tests run with results recorded accurately; no expected fixed test count.
- [ ] Physical-phone HTTPS/auth verification remains pending until Chris performs it or explicitly authorizes hardware testing.
- [ ] Scanner command safety is tested without network scanning; execution/download remains separately approved.

Planned commands: `dotnet test banking-lab/backend/tests/Banking.IntegrationTests/Banking.IntegrationTests.csproj`; from `banking-lab/mobile/banking_mobile`, `flutter analyze` and `flutter test`. These have not been rerun for the documentation-only repair proposal.

## 8. Risks, recovery and delivery notes

- New options validation can stop an API that previously relied on the fallback secret. Provide setup instructions; do not restore the unsafe fallback.
- Session migration requires sign-in again for legacy tokens. Take an approved backup/snapshot and review migration SQL before touching shared data; do not reset or drop the database as recovery.
- Keep authentication unavailable if verification, HTTPS, keys or schema are not ready. Do not weaken checks to keep a partial demo working.
- New endpoints and token policy must be documented as pending until verified. Tests using fake stores are not proof of database behavior; widget tests are not phone checks.
- Deliver a walkthrough explaining session, rotation and atomicity, with changed-file reasons, commands actually run, customization points and remaining manual checks. Preserve historical results as historical, not as fresh proof.
