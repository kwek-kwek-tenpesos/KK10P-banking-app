# Authentication Repair: Batch A

> Historical batch A delivery record. [Batch B](walkthrough-authentication-repair-batch-b.md) now enforces session lifetime/revocation and records PostgreSQL verification. Chris subsequently confirmed clean Flutter analysis and 59 tests passed. Remaining-batch statements below describe the earlier delivery, not current status.

- Date: 2026-09-04
- Audience: Chris and Gio, learning and reviewing the prototype
- Status: Backend verified; mobile changes implemented but execution verification blocked by local tool permissions. This is not completion of the full repair plan.
- Approved policy: access tokens at most 10 minutes, inactivity 15 days, absolute session lifetime 90 days. Chris explicitly amended inactivity from 30 to 15 days.

## What changed and why

1. API startup now validates JWT settings. The built-in signing secret is removed. Missing/sample/invalid keys or out-of-policy lifetimes stop startup with a safe message. Tests supply keys only inside test configuration.
2. Login and refresh require confirmed, enabled, unlocked users. Denied login outcomes share generic 401 responses; lockout lasts five minutes after five failed passwords. Identity update failures do not silently issue tokens.
3. Logout returns 204 when revocation succeeds, 400 for missing/oversized token input, and 503 if persistence fails. Reuse-detection persistence failure also returns 503 instead of claiming revocation succeeded.
4. New access JWTs omit email claims and expire within 10 minutes. Response `expiresInSeconds` is computed from the actual expiration, not hardcoded to 900. New/refreshed refresh-token deadlines use 15 days. The 90-day absolute limit is configured but NOT yet enforced: batch B must persist original session creation/deadlines and must prevent rotation races.
5. Authentication routes reject HTTP without redirecting credentials, limit bodies to 16 KiB including streamed bodies, and return `Cache-Control: no-store`. Per-IP limits run before body processing and expensive password work. Unknown emails are limited too.
6. Flutter registration refuses non-HTTPS API URLs before calling Dio and disables redirects on credential requests. System Info HTTP remains available. No certificate-validation bypass was introduced.
7. Mobile guidance now says 15-128 characters. ASCII length is checked locally. Non-ASCII input is bounded to 512 raw code points and forwarded unchanged so the server can perform NFC normalization and enforce 15-128 normalized code points. This avoids rejecting valid decomposed Unicode or adding a normalization dependency. Server field errors remain visible. Display-name length counts Unicode code points, not UTF-16 units. Duplicate in-flight submissions are blocked.
8. Test hosts use in-process HTTPS URLs and isolated logging. This avoids Windows Event Log permissions affecting assertions; the shipped application's logging is unchanged.

## Sequential logic

```text
Startup -> validate externally supplied signing settings -> start or fail safely
Auth request -> per-IP limit -> HTTPS/body-size guards -> endpoint validation
Login -> credential + current eligibility checks -> persist refresh hash -> issue JWT
Logout -> persist revocation -> 204, or safe 503 on failure
Mobile register -> reject unsafe URL -> disable redirects -> submit -> render server result
```

## Concepts to learn

- **Fail closed:** If required security setup or user eligibility cannot be established, deny the operation instead of falling back to an unsafe default.
- **Rate limiting:** Limit how many requests one caller can start in a time window; this protects resources, while account lockout limits password guessing against an existing account.
- **Unicode normalization:** Visually identical text can have different underlying character sequences. The server converts passwords to NFC consistently before counting/checking them; mobile does not trim or rewrite passwords.
- **Atomic rotation:** Only one competing request should be able to consume a refresh token. Ordinary sequential tests and SaveChanges alone do not prove this; database-level coordination is still batch B work.

## Files changed in this batch

All paths below are repository-relative.

| Path | Responsibility/change |
| --- | --- |
| `banking-lab/backend/Banking.api/Features/Authentication/JwtOptionsValidator.cs` | New safe startup validation |
| `banking-lab/backend/Banking.api/Features/Authentication/AuthenticationRequestGuards.cs` | New HTTPS, bounded-body, no-store and per-IP rate policies |
| `banking-lab/backend/Banking.api/Features/Authentication/TokenService.cs` | Remove fallback key/email claim; policy defaults and accurate expiry |
| `banking-lab/backend/Banking.api/Features/Authentication/ITokenService.cs` | Return internal issued-token metadata with redacted ToString |
| `banking-lab/backend/Banking.api/Features/Authentication/CustomerLoginService.cs` | Eligibility, Identity result/dependency handling and truthful revocation outcomes |
| `banking-lab/backend/Banking.api/Features/Authentication/CustomerLoginContracts.cs` | Remove misleading default response lifetime |
| `banking-lab/backend/Banking.api/Program.cs` | Wire validation/guards and updated API status/algorithm contracts |
| `banking-lab/backend/tests/Banking.IntegrationTests/AuthenticationRepairTests.cs` | New security and failure regression tests |
| `banking-lab/backend/tests/Banking.IntegrationTests/TestAuthenticationConfiguration.cs` | Explicit test-only signing settings and logger isolation |
| `banking-lab/backend/tests/Banking.IntegrationTests/RegistrationTestHost.cs` | HTTPS test clients, persistence failure injection, controllable Identity write failure |
| `banking-lab/backend/tests/Banking.IntegrationTests/CustomerLoginEndpointTests.cs` and `TokenServiceTests.cs` | Updated lifetime, claims, generic errors and 204 logout assertions |
| `banking-lab/backend/tests/Banking.IntegrationTests/CustomerIdentityTests.cs`, `CustomerRegistrationTests.cs`, `IdentityFoundationTests.cs`, `CustomerPasswordPolicyTests.cs`, `SystemInfoEndpointTests.cs`, `OpenApiEndpointTests.cs` | Inject valid test settings after removal of runtime fallback |
| `banking-lab/mobile/banking_mobile/lib/core/errors/app_failure.dart` | Explicit secure-connection-required failure |
| `banking-lab/mobile/banking_mobile/lib/features/authentication/data/services/authentication_api_service.dart` | Pre-send HTTPS check and no redirects |
| `banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/controllers/registration_controller.dart` | Advisory length/bounds, Unicode name counting and duplicate-submit guard |
| `banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/screens/registration_screen.dart` | Correct password guidance |
| `banking-lab/mobile/banking_mobile/test/features/authentication/data/services/authentication_api_service_test.dart` and `presentation/controllers/registration_controller_test.dart` | New transport and Unicode/boundary regression cases; updated fixture expectations |
| `README.md`, `CHANGELOG.md`, `banking-lab/docs/01_Tracking/task.md`, repair plan and historical slice-3 plan | Current setup, approval, results and remaining gates |

No migration, network configuration, SDK source, package dependency, scanner, license or repository visibility change was made. Existing dirty worktree changes belong to the user and remain intact.

## Configuration and safe customization

| Setting | Current meaning |
| --- | --- |
| `Jwt:SigningKey` / `Jwt__SigningKey` | Required private random secret; at least 32 bytes, generated outside source control. Length validation does not prove entropy. |
| `Jwt:Issuer`, `Jwt:Audience` | Defaults BankingLab / BankingMobileApp; must be nonblank and match validation |
| `Jwt:AccessTokenLifetimeMinutes` | Default 10; allowed 1-10; responses use actual remaining seconds |
| `Jwt:SessionInactivityDays` | Default 15; allowed 1-15; used for new refresh deadlines |
| `Jwt:SessionAbsoluteLifetimeDays` | Default 90; allowed up to 90 and not below inactivity; persistence/enforcement pending batch B |

Remove the obsolete `Jwt:RefreshTokenLifetimeDays` from any local configuration when reviewing it: it is no longer consumed. Do not paste private configuration into chat. Store a generated secret using .NET user secrets for local development or an environment variable, never tracked appsettings. User secrets are development storage, not an encrypted production vault.

An API relying on the old fallback will now refuse startup, including System Info. Configure a private key rather than restoring the fallback. A temporary local shell can generate one without printing it:

```powershell
$env:Jwt__SigningKey = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
dotnet run --project banking-lab/backend/Banking.api
```

Run from the repository root. This is a local operator command, not executed by this delivery; a fresh shell-generated key invalidates old access JWTs. Prefer stable privately stored configuration when intentionally testing persistent sessions. The HTTP listener is still diagnostic-only for requests without credentials. A trusted HTTPS endpoint/certificate and the intended hostname must be reviewed before physical-phone registration testing; do not change Tailscale addresses or accept arbitrary certificates to work around this.

Current limits: login 10/minute/IP, registration 5/15 minutes/IP, refresh 60/minute/IP, logout 60/minute/IP. Excess requests receive 429 and Retry-After without queuing. Limits are process-local and reset on restart; no distributed limiter or trusted proxy setup is claimed. The additional refresh per-session limit awaits batch B.

## Verification actually performed

- Initial `dotnet test ... --no-restore --verbosity quiet`: 113 total, 111 passed, 2 failed due to denied Windows Event Log access. Targeted rerun confirmed the logging cause.
- After explicit test-host logging isolation and repairs: existing 113 tests passed.
- After adding regression cases: `dotnet test banking-lab/backend/tests/Banking.IntegrationTests/Banking.IntegrationTests.csproj --no-restore --verbosity quiet` passed **140/140**, zero skipped. No PostgreSQL connection is used by this suite.
- Dart formatter processed the six touched Dart files, then failed while writing user-profile telemetry. This is not a clean successful format-command exit.
- `flutter test --no-pub` stalled before tests in the SDK bootstrap and was stopped. Direct cached Flutter-tool invocation then confirmed denied access to `D:/Development/flutter/bin/cache/lockfile`.
- Direct Dart `analyze --fatal-infos` failed before analysis because user-profile telemetry could not be written. No Flutter test/analyzer pass is claimed.

### Pending user/tooling checks

Follow-up (2026-09-04): Chris ran `flutter analyze` successfully in his terminal but it reported one `prefer_initializing_formals` info in `lib/features/authentication/data/repositories/authentication_repository.dart`. The constructor now uses `AuthenticationRepository(this._secureSessionStore, {this._apiService});`. This initializes the same nullable field, defaults to null when omitted, and preserves the public `apiService:` argument name. The project's Dart constraint is ^3.13.1; [private named initializing formals](https://dart.dev/language/constructors#private-named-parameters) are supported from Dart 3.12. No behavior/test assertions changed. Post-fix analyzer and test results are still pending; the earlier agent-side SDK permission limitation is not a claim that Chris's terminal is blocked.

From `banking-lab/mobile/banking_mobile`, run in your normal development terminal:

```powershell
flutter analyze
flutter test
```

These automated mobile checks do not require PostgreSQL. Do not edit external SDK/cache files or loosen system permissions just to satisfy this task without explicit approval.

Physical checks, after separately reviewed HTTPS setup: verify System Info still loads over the intended diagnostic connection; confirm HTTP registration displays the secure-connection message without sending a password; test HTTPS form errors and keyboard layout on the phone. Live signup is still unavailable until real verification delivery is implemented. Do not mark those checks passed based on widget tests alone.

## Remaining blockers / next batch

The full repair is **not ready for deployment**: refresh rotation races, per-session revocation, session-ID authorization, 90-day absolute expiry and per-session refresh throttling remain batch B. Existing pre-repair JWTs are not automatically revoked by these changes. New migration SQL and a disposable PostgreSQL database require separate approval before application/testing; the shared Chris/Gio database is untouched. ZAP correction/execution remains batch C with its own gate. No fake verification or seeded privileged accounts were added.
