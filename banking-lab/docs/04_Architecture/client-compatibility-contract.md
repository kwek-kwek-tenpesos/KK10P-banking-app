# Client Compatibility Contract

- Status: Implemented candidate; enforcement is disabled by default.
- Platform: Flutter Android client and ASP.NET Core API.
- Candidate: `1.0.1+2`.
- Activation boundary: Gate 8A-R is separate and has not been activated.

## Purpose and trust boundary

Client compatibility lets the API stop unsupported Android builds before authentication, payload handling, database access, or a banking operation. It is an operational compatibility control, not proof of identity: a modified client can forge headers, so authentication, authorization, owner scoping, validation, rate limits, idempotency, and ledger invariants remain authoritative.

Slice 8A changes no PostgreSQL schema or shared data. An update-required response does not revoke a session, clear a refresh token, or remove a pending transfer recovery envelope.

## Canonical request metadata

Every request made through the production Flutter Dio client carries exactly one value for:

```http
X-KK10P-Client-Platform: ANDROID
X-KK10P-Client-Build: 2
```

The platform is case-sensitive. The build is 1–9 ASCII digits, begins with `1`–`9`, and is bounded to `999999999`. Whitespace, signs, decimal notation, zero, leading zeros, partial pairs, duplicates, and oversized values are invalid. Headers never grant access.

## Runtime configuration

```json
"ClientCompatibility": {
  "EnforcementEnabled": false,
  "MinimumAndroidBuild": 2,
  "UpdateUri": ""
}
```

Safe repository defaults leave enforcement off. `MinimumAndroidBuild` must be in the accepted build range. A non-empty `UpdateUri` must be an absolute HTTPS URI with a host and no user information. When enforcement is enabled, that trusted HTTPS URI is mandatory; invalid configuration fails startup.

## Endpoint and responses

`GET /api/v1/client/compatibility` is unauthenticated, HTTPS-only, rate-limited to 30 requests per minute per resolved client IP, accepts no query or body, and returns `Cache-Control: no-store`.

A supported request returns HTTP 200:

```json
{
  "platform": "ANDROID",
  "currentBuild": 2,
  "minimumBuild": 2,
  "updateRequired": false,
  "updateUri": null
}
```

Malformed metadata returns HTTP 400 Problem Details with `code: invalid_client_metadata`. When enforcement is active, missing legacy metadata or a build below the minimum returns HTTP 426 with `code: client_upgrade_required`, platform, nullable current build, minimum build, and the configured HTTPS update URI. Problem responses remain correlated through `traceId` and are non-cacheable.

## Governed route matrix

The middleware governs the exact compatibility route and every path under `/api/v1`, including registration, app-driven email verification/resend, login, refresh, logout, identity, accounts, Development funding, transfers, and Activity. It runs after forwarded-header/correlation/security and rate-limit handling, but before endpoint input guards, authentication, authorization, and handlers.

Only these current routes are exempt:

- exact `/api/v1/system/info`;
- Development/Testing OpenAPI paths outside `/api/v1`; and
- non-API paths.

The compatibility endpoint is handled by the middleware itself. The current `POST /api/v1/auth/verify-email` is a mobile endpoint and is not exempt. Any future browser-only confirmation endpoint needs a new explicit narrow review and tests.

With enforcement disabled, completely missing metadata is allowed on other governed paths for candidate rollout compatibility. Malformed or partial version-aware metadata is always rejected. Enabling enforcement later makes missing metadata a legacy client and returns 426.

## Flutter startup and global handling

```text
read native package build once
  -> validate local Android build
  -> GET compatibility over HTTPS
      -> supported: initialize authentication and restore session
      -> offline/error: retryable startup state, no token clearing
      -> invalid local build: non-bypassable reinstall state
      -> trusted 426: non-bypassable Update Required route
```

Authentication restoration is disabled at the application provider boundary and is started only by the compatibility controller. The shared Dio instance attaches the same resolved metadata to later calls. A strictly validated late 426 publishes one global signal, which takes router precedence over auth, protected routes, and deep links.

Only a 426 with the exact stable code, canonical platform, bounded build values, and an absolute HTTPS update URI becomes `ClientUpgradeRequiredFailure`. A malformed or proxy-generated 426 becomes a generic server failure and cannot supply a launchable link.

The Update Required screen blocks Back/deep-link bypass, supports retry, exposes current/minimum build information, uses the accepted Light/Dark material, and launches only the validated external HTTPS URI. It contains no account, balance, Activity, transfer, credential, or token data.

## Gate 8A-R boundary

This contract does not authorize activation. Gate 8A-R requires a separately approved trusted update URI and runtime change after Chris and Gio have installed and verified build 2 without clearing app data. The gate must prove build 1 is blocked and build 2 remains supported. Rollback disables enforcement and restarts the API; no database restore or session revocation is involved.
