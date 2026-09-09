# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 2026-09-10 — Slice 6 real-device transfer acceptance
- Completed Chris↔Gio physical-device transfer verification, including an auto-clicker duplicate-submission check that moved PHP 1.00 once. Reconciled four intentional transfers with unique idempotency keys, two zero-sum postings each, no malformed journals, and an unchanged PHP 200,000.00 combined balance; interrupted-network recovery remains automated-test verified and Activity/history remains deferred to Slice 7.

### 2026-09-10 — Gate 6R shared internal-transfer rollout
- Backed up and reconciled shared `banking_lab`, quiesced the API, applied only `20260909065721_AddInternalTransfers`, verified the widened two-operation check and unchanged users/accounts/balances/journal totals, then restarted the Development API with a successful read-only health check. No funding or transfer was executed; the small Chris↔Gio phone transfer remains manual.

### 2026-09-09 — KK10P Flutter internal-transfer candidate
- Added a protected Recipient → Amount → Review transfer journey, exact PHP-centavo parsing, strict server receipts, Home transfer/reference-copy actions, one-refresh authentication handling, and customer-scoped secure same-key recovery for rapid taps, restarts, and uncertain outcomes. Flutter analysis, all 203 tests, and an Android debug build pass; all 237 ordinary backend tests pass with 20 opt-in PostgreSQL tests skipped. Shared migration and the first live phone transfer remain gated and were not performed.

### 2026-09-09 — OWASP ZAP Gate B evidence
- Completed an authenticated safe-then-active ZAP gate against a dedicated HTTPS API and disposable `banking_lab_zap_test` database. Safe mode covered the generated 20-target OpenAPI inventory with no FAIL results. Exact PostgreSQL reproduction classified the active logout SQL-injection alert as a false positive and added regression coverage; CORP and production-only HSTS hardening were added. The disposable target was removed, 237 ordinary backend tests and 60 scanner safety checks passed, and the shared API/database remained outside the scan.

### 2026-09-09 — KK10P internal-transfer backend candidate
- Added an authenticated, source-owner-derived PHP internal-transfer API with strict centavo input, PHP 50,000 per-transfer and PHP 100,000 Philippine-day outgoing limits, UUID idempotency, deterministic two-account locking, atomic conserved balances, balanced customer postings, no-store correlated errors, and privacy-safe outcome timing. The constraint-only candidate migration passed six fresh disposable PostgreSQL upgrade/concurrency/constraint tests; 234 ordinary backend and 177 Flutter tests passed with clean analysis. Shared migration, live transfer, Flutter Transfer UI, authenticated active ZAP, Git writes, and production rollout remain pending approval.

### 2026-09-09 — KK10P ledger and Development funding candidate
- Added an append-only balanced PHP journal, atomic non-negative account snapshots, and a Development-only fixed PHP 50,000 self-grant capped at PHP 100,000 per account per Philippine day. Added UUID idempotency, account-row serialization, bounded/rate-limited secure input, a confirmation-gated authenticated Diagnostics action, migration/architecture documentation, and concurrency/security coverage. Verification passed 211 ordinary backend tests, 4/4 fresh disposable PostgreSQL ledger tests, clean Flutter analysis, and 177/177 Flutter tests. After explicit approval and verified backup, only the reviewed migration was applied to shared `banking_lab`. Two separately confirmed grants reconciled to PHP 100,000 with four zero-sum postings; the resulting non-zero response exposed and prompted a fix for Flutter's stale zero-only account parser.

### 2026-09-08 — KK10P clean Home and current-account foundation
- Rebuilt authenticated Home around one truthful API-backed PHP simulator account, with a compact simulator disclosure, flat balance presentation, local balance privacy control, responsive UUID reference, and distinct loading/opening/reconciliation/unconfirmed/error states. Preserved diagnostics, sign-out, request single-flight, session invalidation, and stale-result guards without backend, database, API contract, dependency, or material-token changes. Flutter analysis passed and the complete serialized suite passed 170/170; Chris physically accepted Light/Dark and TalkBack behavior. The optional unopened-customer phone path was not run and remains automated-covered.

### 2026-09-08 — KK10P first-install and authentication surfaces
- Added a truthful first-install Welcome/reusable About experience, persistent Light/Dark/System appearance, coordinated preference/session startup, a non-authorizing known-account presentation hint and prototype-inspired auth/diagnostics composition. Removed the Flutter preview gallery; physical review now uses normal hot reload. No backend, database or API contract changed. Analysis passed, the complete Flutter suite passed 149/149, and Chris accepted every physical Light/Dark Slice 2 checklist item on 2026-09-08.

### 2026-09-08 — Approved KK10P material baseline
- Finalized the physically approved warm-neutral Light and charcoal Dark material tokens, compact paired depth, restrained raised-surface hairlines, blue-action press behavior and calibrated inset shadows without changing API or authentication behavior. Analysis passed and the complete Flutter suite passed 131/131; the APK rebuild was intentionally skipped at Chris's request after hot-reload device verification.

### 2026-09-07 — KK10P dual-theme material proof
- Added independently tuned Light and Dark pure-neumorphic tokens, borderless paired top-left/bottom-right depth, true inset press lighting, and a responsive material proof reachable from API diagnostics without changing API or authentication behavior. Analysis passed, the low-contention Flutter suite passed 130/130, and the arm64 debug APK built; physical-device visual approval remains pending because no ADB device was connected.

### 2026-09-07 — KK10P bank-restrained material and rapid interaction
- Matched ordinary control faces to the pale canvas, replaced navy-derived depth with the neutral `#A3B1C6` shadow family, separated vivid pale-surface accents from contrast-safe filled blues, and centralized native raised/inset feedback at 70 ms. Added cancellation, rapid-tap and single-flight login/registration coverage without a global debounce or copied Kotlin code. Analysis passed, focused checks passed 33/33, the low-memory suite passed 126/126, and the private-HTTPS APK built/installed with data preserved; normal, pressed, rapid-tap and 200% ADB reviews passed with no crash lines and font restoration confirmed, while Chris acceptance and TalkBack remain pending.

### 2026-09-07 — KK10P exaggerated blue neumorphic depth
- Strengthened centralized tile/control/panel lighting with a visible top-left white halo and bottom-right shadow, removed normal/pressed button outlines while preserving focus rings, and replaced the former orange family with accessible blue tokens. Login's support actions now use one reusable always-concave native-button variant with deeper pressed and muted disabled states while preserving behavior. Analysis passed, focused checks passed 20/20, the low-memory suite passed 121/121, and the private-HTTPS APK built/installed with data preserved; normal and 200% ADB reviews passed with font restoration confirmed, while Chris acceptance and TalkBack remain pending.

### 2026-09-07 — KK10P physical color and depth calibration
- Calibrated the shared pale gradients, orange action grade and pressed-shadow opacity from real Android captures. Raised panels now isolate their outer shadow on a backing layer so the physical renderer cannot wash the opaque face blue-gray. Added a layer-isolation regression test; analysis, 12 focused core UI tests and the complete low-memory suite passed 118/118. The private-HTTPS APK was installed over the existing phone app with data preserved, and normal-scale resting/pressed captures passed agent review; Chris's acceptance, 200% visual review and Home/account TalkBack remain pending.

### 2026-09-07 — KK10P true-inset lighting refinement
- Added centralized tile/control/panel lighting levels, reusable surface gradients and a native clipped inner-shadow painter so pressed controls become concave without a UI dependency. Moved registration helper/errors outside raised field bodies and aligned Sign out with tactile secondary actions while preserving behavior. Analysis, 39 focused tests and the complete low-memory suite passed 117/117; the private-HTTPS APK built, with physical normal/large-text and TalkBack acceptance pending.

### 2026-09-07 — KK10P tactile visual-fidelity correction
- Reworked Login and Home hierarchy and added shared embossed native buttons, raised field surfaces, icon tiles, pressed/focused/disabled depth states and dark status-bar icons without changing routes, controllers or API behavior. Analysis, 34 focused tests and the complete low-memory Flutter suite passed 112/112; the corrected APK built, while physical normal/large-text comparison and Home/account TalkBack remain pending.

### 2026-09-07 — KK10P mobile UI foundation
- Applied a centralized accessible hybrid-neumorphic Flutter theme and reusable page/surface components to startup, authentication, email verification, diagnostics, Home and account states without changing routes or API behavior. Added spoken password-toggle labels and responsive foundation tests; analysis passed, the low-memory full suite passed 102/102 and the private-HTTPS debug APK built. Physical Android visual and Home/account TalkBack review remain pending.

### 2026-09-06 — Remote customer-B ownership verification
- Verified Gio's remote Android registration and confirmation through the shared private HTTPS API and loopback Mailpit without remote ADB. User-provided screenshots showed Gio's unopened state without Chris's reference and then a distinct PHP 0.00 account; PostgreSQL confirmed exactly two accounts with two unique owners. TalkBack listening remains pending.

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
