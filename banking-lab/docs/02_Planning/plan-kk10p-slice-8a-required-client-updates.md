# KK10P Slice 8A Plan: Required Client Updates

- Status: Approved and implemented as a build-2 candidate with enforcement disabled; Chris/Gio device acceptance and Gate 8A-R remain pending.
- Prepared: 2026-09-10.
- Predecessor: Slice 7 Activity/history and Gate 7R are complete and physically accepted.
- Platforms: Flutter Android client and ASP.NET Core API.
- Data boundary: No PostgreSQL schema migration, funding, transfer, or shared-data mutation.

Enforcement activation is deliberately excluded from the implementation approval for this slice. A separate Gate 8A-R will be requested only after Chris and Gio have installed and verified the version-aware candidate.

## 1. Delivered Outcome

The API can enforce a configurable minimum supported Android build at the earliest safe request boundary. The Flutter app reports trustworthy local build metadata, checks compatibility before restoring an authenticated session, and shows a dedicated non-bypassable update screen when its build is unsupported.

An old app may show only its historical generic server error because it does not understand the new response, but it must not reach protected banking endpoints after enforcement is activated. A supported app continues to sign in, restore sessions, view accounts, transfer fake money, and load Activity normally.

This is a compatibility and operational control, not an authentication or authorization boundary. A modified client can forge version headers, so all existing authentication, ownership, validation, idempotency, rate-limit, and ledger controls remain authoritative.

## 2. Confirmed Product Decisions

- Slice 8A owns required-client-update detection and blocking.
- The first supported candidate is expected to move from Flutter build `1` to build `2`; the exact human-readable version is confirmed from the repository during implementation.
- Enforcement is disabled when the candidate first ships.
- Chris and Gio install and verify the candidate without clearing application data.
- Gate 8A-R later enables the approved minimum build and HTTPS update destination.
- Existing refresh tokens and server sessions are preserved when an update is required.
- Slice 8B will use a **six-digit local PIN as the primary re-entry method**.
- Fingerprint is an approved companion unlock method for Slice 8B, not a replacement for the six-digit PIN.
- Slice 8B also owns lifecycle locking and an immediate privacy cover for the Android recent-apps snapshot.
- Slice 8A must not add a four-digit PIN, fingerprint authentication, or automatic session revocation.

## 3. Current-State Evidence

Repository inspection found the following gap:

- Flutter currently declares `version: 1.0.0+1`.
- Android already derives `versionCode` and `versionName` from Flutter metadata.
- the shared Dio client sends no platform or build metadata;
- the API has no client-compatibility options, endpoint, or middleware;
- authentication restoration begins as soon as `AuthenticationController` is constructed; and
- Flutter's common error mapper has no typed handling for HTTP 426.

Consequently, a previously installed APK can continue using a valid session until ordinary authentication/session rules reject it.

## 4. Actors and Affected Areas

| Actor or area | Required behavior |
| --- | --- |
| Supported customer app | Pass compatibility check and continue through existing authentication and banking flows. |
| Unsupported/legacy app | Be rejected before authentication, database access, or a protected banking operation. |
| Offline supported app | Show a retryable connectivity state without clearing its session. |
| Chris and Gio | Install and verify the candidate before enforcement activation. |
| API operator | Configure enforcement, minimum Android build, and trusted update URI without a database migration. |
| Flutter startup/router | Resolve local build, check compatibility, then and only then initialize authentication. |
| Shared HTTP/error layer | Attach canonical metadata and convert a valid upgrade response into one global typed signal. |
| PostgreSQL | No schema or shared-data change in Slice 8A. |

## 5. Canonical Client Metadata

Every governed Flutter request sends exactly one value for each header:

```http
X-KK10P-Client-Platform: ANDROID
X-KK10P-Client-Build: 2
```

Rules:

- `X-KK10P-Client-Platform` is the exact canonical value `ANDROID` for this client.
- `X-KK10P-Client-Build` is a bounded positive base-10 integer.
- whitespace, signs, decimals, leading zeros, duplicate values, and oversized values are rejected.
- headers are untrusted input and must never grant authentication or authorization.
- build metadata is safe to log only as bounded structured fields; tokens, credentials, full request bodies, and private account data remain excluded.

## 6. Compatibility Endpoint Contract

Add an unauthenticated, HTTPS-only and rate-limited endpoint:

```http
GET /api/v1/client/compatibility
```

It accepts no request body or query parameters and always uses the existing correlation and `Cache-Control: no-store` behavior.

For a supported build:

```json
{
  "platform": "ANDROID",
  "currentBuild": 2,
  "minimumBuild": 2,
  "updateRequired": false
}
```

For an unsupported build, return HTTP `426 Upgrade Required` using the API's Problem Details envelope with:

- stable code `client_upgrade_required`;
- `platform`;
- `currentBuild` when safely parsed;
- `minimumBuild`; and
- the configured absolute HTTPS `updateUri`.

Malformed version-aware metadata returns HTTP 400 with stable code `invalid_client_metadata`. Missing metadata on a governed route is treated as a legacy client and returns 426 only while enforcement is active.

## 7. Governed and Exempt Routes

The compatibility decision runs before authentication, endpoint input parsing, and database access for all current and future mobile banking routes, including:

- registration, resend-verification, login, refresh, logout, and authenticated identity;
- account and balance reads;
- Development funding;
- internal transfer;
- Activity list and detail; and
- later mobile customer endpoints unless explicitly reviewed otherwise.

Exact exemptions are intentionally narrow:

- the compatibility endpoint, because it performs the check itself;
- the existing system-information/health endpoint;
- Development OpenAPI assets.

The current email-verification endpoint is an app-driven `POST /api/v1/auth/verify-email`, not a browser confirmation page, so it remains governed. A future browser-consumable confirmation route would require an explicit narrow exemption and tests.

The implementation must identify and test the exact route patterns rather than applying broad `/auth` or `/api` exemptions.

## 8. Backend Design

Create a focused `Features/ClientCompatibility` feature containing:

- strongly typed runtime options;
- startup validation;
- strict header parser;
- compatibility decision service;
- early middleware/endpoint filter;
- compatibility endpoint; and
- bounded, non-sensitive structured logging.

Runtime options include:

- enforcement enabled/disabled;
- minimum supported Android build; and
- optional update URI.

Safe repository defaults keep enforcement disabled. Enabling enforcement requires a positive minimum build and an absolute HTTPS update URI; invalid enabled configuration fails startup rather than silently weakening or breaking policy.

The middleware is placed after correlation/security transport handling but before authentication, request guards that parse endpoint payloads, and endpoint execution. Rejection must not read or write PostgreSQL.

## 9. Flutter Design

### Build metadata

- Select and pin a maintained package-info dependency during implementation.
- Resolve the native build number once during asynchronous bootstrap.
- Reject invalid local build metadata locally rather than sending ambiguous values.
- Inject the resolved metadata into the shared Dio client so every governed call is consistent.

### Compatibility-first startup

Startup states are explicit:

```text
resolveLocalBuild
  -> checkingCompatibility
      -> supported -> initializeAuthentication -> normal router
      -> updateRequired -> update-required router branch
      -> offline/error -> retryable startup state
      -> invalidLocalBuild -> non-bypassable diagnostic state
```

`AuthenticationController` initialization must become explicit/deferred. No secure-token read, refresh request, or protected route should occur until compatibility is supported.

### Global late detection

The shared response mapper validates the 426 Problem Details shape and maps it to a dedicated `ClientUpgradeRequiredFailure`. A valid upgrade signal received later—from login, refresh, Home, transfer, Activity, or another governed call—moves the entire app to the same update-required state.

Generic, malformed, or proxy-generated 426 responses are not trusted as update metadata and fall back to normal safe server-failure handling.

### Update-required screen

Add a protected router branch such as `/update-required` with precedence over auth and deep-link redirects. The screen:

- uses the approved Light/Dark KK10P neumorphic material and blue accent;
- explains that this app build is no longer supported;
- shows current and minimum build values without exposing sensitive state;
- offers an Update action only for a validated configured HTTPS URI;
- offers Retry for a newly installed build or recovered connectivity;
- cannot be bypassed with Android Back or a deep link;
- suppresses automatic refresh/retry loops behind the screen; and
- remains usable at 320 logical pixels, 200% text, and with TalkBack.

The update state must preserve secure session material and any unresolved transfer/idempotency envelope. It must not silently sign the customer out or clear a pending operation.

## 10. Rollout and Gate 8A-R

### Phase 1 — Version-aware candidate

1. Implement backend and Flutter support with enforcement disabled.
2. Bump the candidate from build 1 to build 2 (normally `1.0.1+2`, subject to current repository version evidence).
3. Run complete automated checks and build the Android APK.
4. Create the authorized candidate commit for Gio to pull only after implementation review.

### Phase 2 — Dual-device verification

1. Chris and Gio install build 2 without clearing app data.
2. Confirm existing sessions still restore and all current slices work.
3. Confirm injected/mock compatibility scenarios render the Update Required UI.
4. Retain one build-1 APK or reproducible old-build path for the enforcement proof.

### Phase 3 — Separate Gate 8A-R

Only after explicit Gate 8A-R approval:

1. record the current runtime configuration and health baseline;
2. configure an approved absolute HTTPS update URI;
3. set minimum Android build to `2` and enable enforcement;
4. restart the API; PostgreSQL does not need to be quiesced or migrated;
5. prove build 1 is blocked from governed endpoints;
6. prove build 2 continues to work using read-only checks first; and
7. record rollback and final device evidence.

Rollback disables enforcement and restarts the API. It does not restore a database or revoke sessions.

## 11. Error and Edge Cases

- Offline during startup shows Retry and does not clear the token.
- A build exactly equal to the minimum is supported.
- A future positive build is supported.
- Missing metadata is allowed while enforcement is disabled and blocked as legacy while enabled.
- Duplicate or malformed headers are rejected deterministically.
- Invalid enabled server configuration fails startup.
- A 426 during refresh does not become a misleading signed-out state.
- A 426 during a pending transfer preserves the exact idempotency key and payload.
- Rapid Retry taps are single-flight and do not create request storms.
- Android Back, notification links, and verification deep links cannot bypass the update screen.
- The old APK is allowed to show a generic failure, but no governed operation may execute.
- The current app-driven email-verification request is governed like the other mobile auth routes.

## 12. Security, Privacy, and Reliability Requirements

- Compatibility headers never replace authentication, authorization, account ownership, or transaction validation.
- Parser length and numeric bounds prevent abusive allocations and ambiguous comparisons.
- Upgrade responses are correlated and non-cacheable.
- Only an absolute HTTPS update URI from trusted runtime configuration can be launched.
- No tokens, credentials, account references, transfer payloads, or update query secrets appear in logs.
- Unsupported requests are rejected before endpoint effects or database access.
- No server session is revoked solely because its client build is unsupported.
- Existing rate limiting remains effective; compatibility Retry is single-flight in Flutter.

## 13. Expected Repository Changes

Backend:

- `banking-lab/backend/Banking.api/Features/ClientCompatibility/` for options, parsing, middleware, and endpoint;
- `banking-lab/backend/Banking.api/Program.cs` for validated registration and early pipeline placement;
- safe defaults in API configuration;
- endpoint, parser, route-matrix, exemption, and logging tests; and
- OpenAPI expectations where applicable.

Flutter:

- `pubspec.yaml` and lockfile for pinned package/build metadata support and, if selected, safe URL launching;
- asynchronous bootstrap and application startup state;
- shared Dio request metadata;
- typed app failure and API error mapping;
- compatibility models, service, repository/controller, and screen;
- router precedence and deferred authentication initialization; and
- unit, controller, router, widget, and regression tests.

Documentation upon implementation:

- a canonical client-compatibility architecture contract;
- a proportionate Slice 8A walkthrough with exact PowerShell commands;
- this tracker and roadmap;
- changelog only after behavior is delivered; and
- a separate Gate 8A-R record if activation is later approved.

## 14. Automated Verification

### Backend

- Options validation and disabled/enabled configuration tests.
- Strict parser tests for valid, missing, duplicate, signed, decimal, padded, zero, negative, leading-zero, and oversized builds.
- Compatibility endpoint 200/400/426 contract tests.
- Governed route matrix proving rejection occurs before auth, body parsing, and handlers.
- Exact exemption tests for system information, compatibility, and Development OpenAPI; the current app-driven verification endpoint remains governed.
- Existing API tests updated to send supported metadata where appropriate.
- Logging assertions that sensitive values are absent.
- Focused and complete backend suites without requiring shared PostgreSQL.

### Flutter

- Native build resolution and invalid-local-build tests.
- Dio header attachment tests.
- Strict 200 and 426 response parsing tests.
- Startup ordering proving compatibility finishes before authentication restoration.
- Offline/error and single-flight Retry controller tests.
- Global late-426 routing tests from auth and protected calls.
- Tests proving tokens and pending transfer/idempotency data are retained.
- Router tests proving Back/deep links cannot bypass the update state.
- Light/Dark, narrow-width, 200%-text, semantics, and TalkBack-label widget tests.
- Existing auth, Home, transfer, and Activity regression suites.
- Dart formatting, static analysis, complete low-memory Flutter tests, and debug APK build.

## 15. Manual Device Verification

Before Gate 8A-R, both Chris and Gio verify build 2:

- install/update succeeds without clearing app data;
- an existing signed-in session restores normally;
- signed-out registration/login still work;
- Home, Transfer, and Activity still load;
- Light/Dark/System selection remains stable;
- simulated update-required UI is clear and non-bypassable;
- Retry remains responsive during rapid taps;
- TalkBack reads the reason and actions in a sensible order; and
- no private banking content is newly exposed in the update UI.

During the separately approved Gate 8A-R:

- old build 1 cannot access any governed banking endpoint;
- build 2 passes compatibility and remains usable;
- system information and Development OpenAPI remain reachable;
- no funding or transfer is created for the gate; and
- disabling enforcement restores compatibility without a database action.

## 16. Acceptance Criteria

- [x] Runtime configuration defines an enforceable minimum Android build with safe disabled defaults.
- [x] The API strictly accepts one canonical platform/build header pair.
- [x] Flutter sends build metadata consistently from one resolved source.
- [x] Compatibility is decided before authentication restoration or a protected request.
- [x] With enforcement enabled in isolated automated tests, missing or older builds receive a non-cacheable correlated 426 before endpoint effects.
- [x] A build equal to or newer than the minimum remains supported.
- [x] A valid 426 from any governed call opens one global non-bypassable Update Required screen.
- [x] Offline and malformed-server cases remain distinct from a trusted update-required decision.
- [x] Update-required state preserves tokens and unresolved transfer idempotency data.
- [x] Exact system-information, compatibility, and Development OpenAPI exemptions are tested; mobile verification remains governed.
- [x] No money movement, database migration, shared-data mutation, or automatic session revocation is introduced.
- [x] Logs contain no credentials, tokens, private account data, or transfer payloads.
- [x] Existing backend and Flutter regression suites pass.
- [ ] Chris and Gio verify build 2 before Gate 8A-R is requested.
- [ ] Gate 8A-R separately proves old build 1 blocked and build 2 supported.

## 17. Explicitly Deferred Slice 8B

Slice 8B will be planned and approved separately. Its confirmed direction is:

- six-digit local PIN as the primary returning-user re-entry method;
- fingerprint as a companion convenience unlock after the PIN is established;
- secure enrollment/recovery rules that do not weaken server authentication;
- locking on cold start, background timeout, and other reviewed lifecycle boundaries; and
- an immediate privacy cover so recent-apps does not reveal Activity, balances, or receipts.

The precise lock timeout, biometric fallback behavior, device-change handling, secure-storage design, and recovery UX remain Slice 8B planning decisions.

## 18. Approval Boundary

Approval of this plan authorizes implementation, tests, documentation, a build-2 candidate APK, and the normal pre-Gio commit workflow for Slice 8A with enforcement disabled.

It does **not** authorize:

- enabling minimum-build enforcement on the shared API;
- publishing or changing an external tunnel/update destination;
- revoking sessions or clearing secure client data;
- six-digit PIN, fingerprint, or lifecycle/privacy-lock implementation;
- a database migration, funding, or transfer;
- pushing a Git commit; or
- Slice 8C navigation/Home work.

Those actions require their own stated approval or later slice.
