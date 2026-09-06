# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 2026-09-06 — Physical customer-account verification (customer A)
- Installed the current debug APK in place on the Infinix device and verified private Tailscale HTTPS diagnostics, local Mailpit registration/confirmation, authenticated unopened state, explicit PHP 0.00 account opening, PostgreSQL persistence, force-stop restoration, recoverable API-outage Retry, 200% text/scroll reachability and server-backed logout. Cross-customer B isolation and TalkBack listening remain pending; no data was reset or deleted and no ZAP scan ran.

### 2026-09-06 — Shared customer-account schema rollout
- Verified a custom-format backup of shared local `banking_lab`, reviewed the exact forward SQL and applied only `20260906042449_AddCustomerAccounts`. Post-checks confirmed an initially empty account table, PHP/zero constraints, restricted ownership, unique owner indexing, unchanged identity/session/token counts and no pending EF model changes. ZAP remains separately gated.

### 2026-09-06 — Disposable PostgreSQL account verification
- Created the approved fresh local `banking_lab_accounts_test` target and passed all four guarded account upgrade, concurrency and constraint tests. Confirmed the account migration only in that disposable database; shared `banking_lab`, live API/device behavior and ZAP remain untouched and separately gated.

### 2026-09-06 — Customer accounts and zero balances
- Added explicit opening and owner-only retrieval of one PHP simulator account at zero, strict transport/input/cache/rate guards, an additive unapplied account migration, and Flutter Home account/retry states with session-generation and secure-storage race protection. Verified 196 database-free backend tests, 101 Flutter tests and clean analysis; ten PostgreSQL tests were skipped. Database execution, shared rollout, physical-phone checks and ZAP remain pending approval.

### 2026-09-05 — End-to-end customer authentication
- Added provider-neutral SMTP verification with a loopback-only optional Mailpit profile, one-use confirm/resend endpoints, exact-loopback forwarded-header trust, Flutter login/session restoration/logout, protected routing and a placeholder customer home. Stored private local signing and Mailpit settings outside Git and preserved shared data. Verified clean Flutter analysis, 73 mobile tests, 176 database-free backend tests, six disposable-PostgreSQL tests, the local adapter journey and the complete physical-phone registration/confirmation/restoration/logout flow over private Tailscale Serve HTTPS.

### 2026-09-05 — Shared customer-session schema rollout
- Backed up the exact empty shared `banking_lab` PostgreSQL database to Git-ignored local storage, verified the archive catalog, confirmed a drift-free EF model, and applied only `20260904152654_AddCustomerSessions`. Post-checks confirmed the migration, nullable compatibility link, session table, indexes and restrictive foreign keys with zero user/session data changed. Documented the proposed end-to-end verification and mobile-session slice; application implementation, private signing, Tailscale HTTPS and phone verification remain pending.

### 2026-09-04 — Authentication repair, batch C and review
- Made ZAP tooling preview-only by default, removed shell-string execution, restricted approved scans to local diagnostic GET traffic, disabled automatic pulls/updates and added honest exit/report handling. Added narrow generated-artifact ignores without deleting files. Review reproduced and fixed session expiry during refresh persistence with a typed 401 outcome and regression tests. Verified 60 offline scanner checks and 163 backend passes (six PostgreSQL tests skipped); no actual scan, download, database or Tailscale changes. Archived completed implementation checklists; rollout/authentication integration remain pending.

### 2026-09-04 — Authentication repair, batch B
- Added persisted session families with 15-day sliding inactivity, 90-day absolute expiry, session-bound JWT authorization, atomic refresh rotation, family logout/replay revocation and a 30/minute session refresh budget. Added protected `/api/v1/auth/me` and safe wrapped-database-failure handling. Verified 166/166 backend tests, including six PostgreSQL cases; Chris confirmed clean Flutter analysis and 59 tests. Additive migration applied only to the authorized disposable database; shared data/Tailscale unchanged. Old sessionless credentials require fresh login after rollout. See the batch B walkthrough for migration/rollback cautions and remaining integration work.

### 2026-09-04 — Mobile constructor lint follow-up
- Simplified AuthenticationRepository's optional API-service initialization using Dart's initializing formal; existing apiService callers and runtime behavior are unchanged. Chris reported one analyzer lint; post-fix mobile analysis/tests remain pending.

### 2026-09-04 — Authentication repair, batch A
- Removed the fallback signing key; added startup validation, verified-user eligibility, truthful logout failures, HTTPS/body-size/no-store/IP-rate guards, accurate 10-minute JWT metadata and 15-day refresh deadlines. Aligned mobile password guidance and blocked cleartext/redirected credential requests. Backend: 140/140 tests passed. Mobile analysis/tests blocked by local SDK/telemetry permissions. The 90-day absolute limit, session-family revocation and atomic rotation remain batch B; no migrations or scans ran. See the batch A walkthrough for setup changes and limitations.

### Added
- Implemented Slice 3 Customer Login, JWT access tokens, and rotating refresh tokens (`BL-SEC-005`):
  - Added `CustomerRefreshToken` entity, EF Core migration, and PostgreSQL table with unique SHA-256 token hash indexing.
  - Implemented `TokenService` generating 15-minute JWT access tokens and 256-bit entropy Base64Url refresh tokens.
  - Implemented `CustomerLoginService` with anti-enumeration protection, timing attack mitigation, Identity lockout handling, token rotation, and compromise detection.
  - Exposed `POST /api/v1/auth/login`, `POST /api/v1/auth/refresh`, and `POST /api/v1/auth/logout` endpoints in Minimal API.
  - Added integration tests in `CustomerLoginEndpointTests` and `TokenServiceTests` (111 backend tests passing, 54 mobile tests passing).
- Implemented Flutter Customer Registration UI (`RegistrationScreen`) and Riverpod state management (`RegistrationController`) under `BL-MOB-002`.
- Added `ValidationFailure` to `AppFailure` hierarchy and mapped HTTP 400 ProblemDetails in `api_error_mapper.dart`.
- Added `AuthenticationApiService` with Dio and wired `register` method in `AuthenticationRepository`.
- Added unit and widget tests for models, service, controller, and screen (54 mobile tests passing).
- Exposed public customer registration endpoint `POST /api/v1/auth/register` in `Program.cs` with anti-enumeration protection.
- Applied EF Core Identity migration `20260903171002_AddCustomerIdentity` to PostgreSQL container.
- Added comprehensive integration tests in `RegistrationEndpointTests.cs` verifying HTTP 202 Accepted, 400 Bad Request, 503 Unavailable, and Mass Assignment rejection.
- Standardized Docs_ProjectWorkflowStarterKit_v2.0 documentation hierarchy in `banking-lab/docs/` (00_Drafts through 07_Archive).
- Configured root `AGENTS.md` Project Profile for Banking Lab.
- Added `.aiignore` and `.cursorignore` root context protection rules.
- Initialized active task tracking in `banking-lab/docs/01_Tracking/task.md`.
- Deployed implementation plan and walkthrough templates in `banking-lab/docs/02_Planning/` and `banking-lab/docs/03_Walkthroughs/`.
