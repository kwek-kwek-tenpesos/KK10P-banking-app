# Slice 8A Walkthrough: Required Client Updates Candidate

- Date: 2026-09-10.
- Delivery state: Build-2 candidate implemented and automated checks pass; enforcement remains disabled. Chris/Gio device acceptance and Gate 8A-R are pending.
- Plan: [Slice 8A](../02_Planning/plan-kk10p-slice-8a-required-client-updates.md).
- Contract: [Client compatibility](../04_Architecture/client-compatibility-contract.md).

## Delivered outcome

The Android candidate is now `1.0.1+2` and reports one canonical platform/build pair on shared Dio requests. At real app startup, KK10P validates the native build, checks the HTTPS compatibility endpoint, and only then restores an existing authenticated session. Offline checks show Retry without clearing the session.

The API has strict build parsing, validated runtime options, an early governed-route boundary, a rate-limited compatibility endpoint, correlated non-cacheable 400/426 errors, and safe structured logging. The default remains `EnforcementEnabled: false`, so this candidate does not lock out Gio's or Chris's older install yet.

A trusted upgrade response from startup or any later API call takes global router precedence and shows the same non-bypassable Light/Dark Update Required screen. Tokens, sessions, account data, and unresolved transfer recovery data are retained.

## Concepts used in this slice

- **Compatibility before authentication:** no token read or refresh starts until the build is accepted.
- **Fail-closed parsing:** ambiguous local metadata, headers, successful responses, and 426 payloads are rejected.
- **Narrow exemptions:** only exact system information and non-API Development OpenAPI remain outside the mobile route gate.
- **Global late signal:** any governed call can move the router to Update Required without signing out.
- **Operational separation:** candidate support and enforcement activation are two different releases/gates.
- **Preserved recovery state:** update handling does not destroy refresh tokens or transfer idempotency envelopes.

## Logic flow

```text
Flutter bootstrap reads native build 2
  -> shared Dio receives ANDROID/build headers
  -> GET /api/v1/client/compatibility
      -> 200 supported -> restore saved authentication -> normal app
      -> network/server failure -> retryable startup surface
      -> trusted 426 -> global /update-required
      -> malformed response/local build -> safe non-bypassable failure

Later governed API call
  -> strict 426 mapper
  -> global upgrade signal
  -> /update-required without clearing local secure state
```

## Important repository paths

| Path | Purpose |
| --- | --- |
| `banking-lab/backend/Banking.api/Features/ClientCompatibility/` | Options, validation, canonical parser, early middleware, rate limiter, and endpoint. |
| `banking-lab/backend/Banking.api/Program.cs` | Pipeline registration before input/auth/database work. |
| `banking-lab/backend/Banking.api/appsettings.json` | Safe enforcement-disabled defaults. |
| `banking-lab/backend/tests/Banking.IntegrationTests/ClientCompatibilityTests.cs` | Parser, config, response, route, and exemption proofs. |
| `banking-lab/mobile/banking_mobile/lib/features/client_compatibility/` | Native metadata, response model, API service, startup controller, and update UI. |
| `banking-lab/mobile/banking_mobile/lib/core/api/dio_provider.dart` | Canonical headers and global late-426 signal. |
| `banking-lab/mobile/banking_mobile/lib/app/app_router.dart` | Compatibility-first router precedence and retry startup state. |
| `banking-lab/mobile/banking_mobile/pubspec.yaml` | Candidate `1.0.1+2` plus pinned package-info and URL-launch dependencies. |

## Automated verification

From repository root:

```powershell
dotnet test .\banking-lab\backend\tests\Banking.IntegrationTests\Banking.IntegrationTests.csproj --no-restore
```

Result: 279 passed, 0 failed; 21 opt-in PostgreSQL tests skipped as designed. Slice 8A has no database migration and did not require shared `banking_lab`.

From `banking-lab/mobile/banking_mobile`:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Result: formatting and analysis are clean, and all 228 Flutter tests pass. The debug APK assembled successfully at `build/app/outputs/flutter-apk/app-debug.apk`.

On this Windows workstation, the normal APK command encountered a Kotlin incremental-cache path error because the Pub cache is on `C:` while the project is on `D:`. If that same local-only error recurs, stop Gradle, clean only generated Flutter output, restore packages, and run the equivalent build with incremental Kotlin compilation disabled:

```powershell
Set-Location D:\OtherProjects\KK10P-banking-app\banking-lab\mobile\banking_mobile\android
.\gradlew.bat --stop
flutter clean
flutter pub get
.\gradlew.bat app:assembleDebug "-Pkotlin.incremental=false" --no-daemon
```

This workaround changes no source, database, or runtime compatibility setting.

## Run the candidate for phone verification

Start PostgreSQL and Mailpit from repository root:

```powershell
docker compose -f .\banking-lab\infrastructure\compose\compose.dev.yml --profile email up -d postgres mailpit
docker compose -f .\banking-lab\infrastructure\compose\compose.dev.yml --profile email ps
```

Start the API in a second PowerShell window:

```powershell
Set-Location D:\OtherProjects\KK10P-banking-app\banking-lab\backend\Banking.api
dotnet run --launch-profile http
```

Run Flutter in a third PowerShell window using the already approved HTTPS API address:

```powershell
Set-Location D:\OtherProjects\KK10P-banking-app\banking-lab\mobile\banking_mobile
flutter devices
flutter run -d YOUR_DEVICE_ID --dart-define=API_BASE_URL=https://YOUR-APPROVED-HTTPS-HOST
```

Use `r` for hot reload, `R` for hot restart, and `q` to stop. Do not commit a device ID, private host, secret, token, account reference, or private screenshot.

## Chris/Gio candidate checklist

1. Pull the candidate commit and update/install build 2 without clearing app data.
2. Confirm the existing session restores to the correct customer. If signed out beforehand, confirm registration/login/verification still work.
3. Confirm Home balance/account, open and cancel the Transfer screen without submitting, read Activity list/detail, and sign out. Do not create funding or transfers for this candidate check.
4. Confirm Light, Dark, and System appearance remain stable through a cold restart.
5. Briefly stop the API before startup: confirm a safe retry state appears and the saved session works after the API returns.
6. Confirm Back/deep links cannot reveal protected screens while startup compatibility is pending.
7. At roughly 320 px split-screen width and 200% text, confirm the retry/update surfaces scroll without clipped actions.
8. With TalkBack, confirm the compatibility progress/reason/build information/actions are understandable and contain no private account data.
9. Rapidly tap Retry: confirm only one logical compatibility check remains active and the app does not flicker or request-storm.

Because enforcement is deliberately disabled, an ordinary old build remains allowed during this candidate test and the real Update Required screen is not expected from shared runtime configuration. The strict 426/update UI is covered by automated injection until Gate 8A-R is separately approved.

## Gate 8A-R is not active

Do not set `EnforcementEnabled` to `true`, publish an update destination, or expect build 1 to be blocked yet. After both devices accept build 2, retain an old build-1 APK/reproducible install and request Gate 8A-R. That gate changes runtime configuration only; it requires no database migration, funding, or transfer.
