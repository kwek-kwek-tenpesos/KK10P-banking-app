# Task Tracking: Slice 8A Required Client Updates

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Build-2 candidate implemented, fully verified, and committed with enforcement disabled; Chris/Gio device acceptance and Gate 8A-R remain pending.
- Parent Roadmap: [KK10P prototype-to-Flutter roadmap](../02_Planning/plan-kk10p-prototype-to-flutter-roadmap.md).
- Active Plan: [Slice 8A required-client-update plan](../02_Planning/plan-kk10p-slice-8a-required-client-updates.md).
- Completed Slice: [Slice 7 archive](archive/task-2026-09-10-kk10p-slice-7-activity-history.md).
- Current Contracts: [Authentication](../04_Architecture/customer-authentication-contract.md), [accounts](../04_Architecture/customer-accounts-contract.md), [internal transfer](../04_Architecture/internal-transfer-contract.md), [Activity/history](../04_Architecture/activity-history-contract.md), and [client compatibility](../04_Architecture/client-compatibility-contract.md).
- Confirmed Slice 8B Direction: Six-digit local PIN is the primary re-entry method; fingerprint is a later companion. Lifecycle locking and the recent-apps privacy cover belong to that separately planned slice.
- Shared-State Boundary: Slice 8A requires no PostgreSQL migration, funding, transfer, or shared-data mutation.
- Runtime Boundary: Candidate implementation keeps minimum-build enforcement disabled. Activation requires separate Gate 8A-R approval after Chris and Gio install and verify the supported build.
- Current Execution State: Chris and Gio pull/install build 2 and complete the candidate checklist. Do not activate Gate 8A-R or push from Codex.

## Active Checklist

- [x] Record Chris/Gio acceptance and archive completed Slice 7.
- [x] Inspect current Flutter versioning, shared Dio setup, startup/auth ordering, router, API pipeline, configuration, and error mapping.
- [x] Define canonical Android build headers and strict parsing rules.
- [x] Define the compatibility endpoint, governed-route matrix, and narrow exemptions.
- [x] Define compatibility-first Flutter startup, global late-426 handling, and Update Required UI.
- [x] Separate disabled candidate delivery from the later Gate 8A-R enforcement activation.
- [x] Define backend, Flutter, security, error, edge-case, automated, and manual acceptance criteria.
- [x] Record six-digit PIN, fingerprint companion, lifecycle lock, and privacy cover as Slice 8B.
- [x] Obtain explicit approval for the Slice 8A plan.
- [x] Implement Slice 8A with enforcement disabled.
- [x] Complete automated/build verification and create the authorized candidate commit for Gio to pull.
- [ ] After dual-device acceptance, request Gate 8A-R separately.

## Candidate Verification Record

- Backend: 279 passed, 0 failed, and 21 opt-in PostgreSQL tests skipped; no shared PostgreSQL test was enabled.
- Flutter: formatting clean after normalization, analysis clean, and all 228 tests passed.
- Android: debug APK assembled successfully. Kotlin incremental compilation is disabled in the Android project so ordinary Flutter builds remain deterministic when the Pub cache is on `C:` and the project is on `D:`.
- Chris device build smoke: build `1.0.1` / code `2` installed in place on the Infinix, cold-launched to the Sign In screen in about 2.3 seconds, stayed running, and emitted no fatal Flutter/Android error. The device was signed out, so authenticated restoration and the remaining candidate checklist are still pending.
- Runtime configuration: `ClientCompatibility:EnforcementEnabled` remains `false`; Gate 8A-R was not activated.
- Data boundary: no migration, funding, transfer, or shared-database write was performed.
