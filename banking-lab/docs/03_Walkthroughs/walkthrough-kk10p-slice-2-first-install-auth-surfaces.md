# Walkthrough: KK10P Slice 2 First-Install and Authentication Surfaces

- Delivered: 2026-09-08
- Status: Implementation and automated checks complete; physical-phone acceptance pending
- Audience: Chris, Gio and future Flutter contributors or QA reviewers
- Purpose: Explain the delivered Slice 2 behavior, show how to run it safely on Windows and provide a repeatable physical-device acceptance procedure
- Plan: [Slice 2 first-install, appearance and auth surfaces](../02_Planning/plan-kk10p-slice-2-first-install-auth-surfaces.md)
- Canonical design: [KK10P mobile UI design system](../05_Design/kk10p-mobile-ui-design-system.md)
- Authentication contract: [Customer authentication contract](../04_Architecture/customer-authentication-contract.md)

## 1. Delivered Outcome

The Flutter app now reads local experience preferences and restores the secure session during startup. A valid server-backed session opens protected Home. A signed-out first installation opens a truthful Welcome screen; after the customer chooses Sign In or Create Account, later signed-out starts open Login. No artificial splash delay, evaluator bypass or unsupported banking/security claim was added.

Welcome content remains available through About. Light, Dark and System appearance choices persist across app reconstruction. Login, Registration, Email Verification and API Diagnostics use the approved Slice 1 material and prototype-inspired hierarchy while retaining their existing repository and controller calls.

This slice did not change ASP.NET Core, PostgreSQL, migrations, API request/response models or account behavior. The Kotlin prototype remained a read-only visual/layout reference.

## 2. Concepts Used in This Slice

### 2.1 Local experience preference

A local experience preference controls presentation on one installation. Examples are the selected appearance and whether the introduction has already been acknowledged. It is not proof of identity and must never grant access to protected data.

The Slice 2 keys are:

- `experience.v1.appearance`
- `experience.v1.introduction_completed`
- `experience.v1.known_account_attached`

They contain no email, name, customer ID, password or token.

### 2.2 Authentication session

An authentication session is the server-authorized login state. The access token stays in memory and the rotating refresh token remains in platform secure storage. Only this authenticated state can open `/home`; the local introduction and known-account flags cannot bypass that guard.

### 2.3 Coordinated startup

Coordinated startup means the router waits for both required reads—the local experience snapshot and secure-session restoration—before choosing the first customer screen. The progress indicator represents those real operations; there is no timer that merely imitates work.

### 2.4 Protected routing

A protected route is a screen that requires authenticated state. In this app, `/home` checks `AuthenticationState.isAuthenticated`. Even corrupt or manually altered experience preferences still produce a signed-out route because they are never treated as authorization.

### 2.5 Hot reload versus hot restart

Flutter hot reload (`r`) injects most Dart UI changes while preserving the current app state. Hot restart (`R`) reconstructs the Dart application and is better for checking startup routing and preference persistence. Neither operation clears Android secure storage or simulates a first installation.

## 3. Logic Flow

```text
Launch Flutter app
  -> initialize AppPreferencesController
  -> initialize AuthenticationController
  -> show real startup progress while either is pending
  -> authenticated session exists
       -> protected Home
  -> no authenticated session + introduction incomplete
       -> Welcome
  -> no authenticated session + introduction complete
       -> Login

Welcome
  -> optional Light/Dark/System selection
  -> Sign in or Create account
  -> persist introduction completion
  -> open the selected existing auth route

Successful login or session restoration
  -> persist non-identifying known-account hint
  -> open protected Home

Session expiry or retryable restore failure
  -> return to Login
  -> preserve known-account hint
  -> keep Create Account hidden

Explicit Sign out
  -> revoke the server session where possible
  -> remove local credentials
  -> after confirmed local removal, clear known-account hint
  -> return to Login with Create Account visible
```

## 4. Important Repository Paths

| Path | Responsibility |
| --- | --- |
| `banking-lab/mobile/banking_mobile/lib/core/preferences/app_preferences_store.dart` | Versioned local experience keys and storage adapter |
| `banking-lab/mobile/banking_mobile/lib/core/preferences/app_preferences_controller.dart` | Loading, safe defaults, persistence and non-blocking warnings |
| `banking-lab/mobile/banking_mobile/lib/app/app.dart` | Converts the saved appearance into Flutter `ThemeMode` |
| `banking-lab/mobile/banking_mobile/lib/app/app_router.dart` | Coordinates startup and protects Home |
| `banking-lab/mobile/banking_mobile/lib/core/ui/kk_appearance_menu_button.dart` | Compact appearance menu, full selector and preference warning |
| `banking-lab/mobile/banking_mobile/lib/features/onboarding/presentation/screens/welcome_screen.dart` | First-install Welcome and reusable About composition |
| `banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/screens/login_screen.dart` | Login, resend verification and separated information actions |
| `banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/screens/registration_screen.dart` | Existing three-field registration in the approved material |
| `banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/screens/email_verification_screen.dart` | Existing one-use confirmation states |
| `banking-lab/mobile/banking_mobile/lib/features/system_info/presentation/screens/system_info_screen.dart` | Real diagnostics plus About and material-proof entries |
| `banking-lab/infrastructure/compose/compose.dev.yml` | PostgreSQL and optional Mailpit development containers |
| `banking-lab/backend/Banking.api/Properties/launchSettings.json` | Committed local API endpoint and Development environment |

The former `lib/previews/banking_lab_preview.dart` gallery was removed. Visual calibration now uses the real application through normal `flutter run` hot reload.

## 5. Prerequisites

Install and configure the tools listed in the root [README](../../../README.md):

- .NET 10 SDK;
- Flutter stable and Android SDK tooling;
- Docker Desktop with Docker Compose;
- Tailscale on the host and phone for credential-bearing physical-device traffic;
- USB debugging if the phone is connected over ADB.

The existing untracked Compose `.env` and .NET user-secrets must already be configured. Never paste their real values into documentation, chat, screenshots or commits.

Use separate terminals for Docker checks, the long-running API and the long-running Flutter process.

## 6. Open the Repository

### PowerShell

```powershell
Set-Location 'D:\OtherProjects\KK10P-banking-app'
```

### Command Prompt

```bat
cd /d D:\OtherProjects\KK10P-banking-app
```

Optional tool check in either shell:

```text
dotnet --info
docker compose version
flutter --version
flutter doctor
flutter devices
tailscale version
```

Expected result: the tools return versions, `flutter doctor` has no blocking Android error and the intended phone appears in `flutter devices`.

## 7. Start PostgreSQL and Mailpit

Docker Desktop being open does not automatically start this repository's containers. From the repository root, run the following in either PowerShell or Command Prompt:

```text
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml --profile email up -d postgres mailpit
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml --profile email ps
```

Expected result:

- `postgres` reports `healthy`;
- `mailpit` reports `Up`;
- PostgreSQL is mapped to host port `5432`;
- Mailpit is loopback-only on `127.0.0.1:1025` and `127.0.0.1:8025`.

Mailpit is needed for Registration and Resend Verification testing. Open `http://localhost:8025` on the development PC to read the captured fake-account email.

If Compose reports `POSTGRES_PASSWORD` is missing, confirm this untracked file exists:

```text
banking-lab/infrastructure/compose/.env
```

Its syntax is:

```dotenv
POSTGRES_PASSWORD=YOUR_LOCAL_DEVELOPMENT_PASSWORD
```

Use the already configured local development value; do not commit the file. Slice 2 has no migration, so do not run `dotnet ef database update` for this visual review.

## 8. Start and Verify the ASP.NET Core API

Open a second terminal.

### PowerShell

```powershell
Set-Location 'D:\OtherProjects\KK10P-banking-app\banking-lab\backend\Banking.api'
dotnet run --launch-profile http
```

### Command Prompt

```bat
cd /d D:\OtherProjects\KK10P-banking-app\banking-lab\backend\Banking.api
dotnet run --launch-profile http
```

Leave this terminal running. Expected startup line:

```text
Now listening on: http://127.0.0.1:5255
```

Verify it from a separate PowerShell terminal:

```powershell
Invoke-RestMethod -Uri http://127.0.0.1:5255/api/v1/system/info
```

Or from Command Prompt:

```bat
curl.exe --fail http://127.0.0.1:5255/api/v1/system/info
```

Expected JSON fields:

```json
{
  "name": "Banking API",
  "version": "v1.0.0",
  "environment": "Development"
}
```

This diagnostic endpoint does not prove PostgreSQL or Login works. The Compose health check and a real test login cover those separately.

## 9. Provide Private HTTPS to the Phone

Credential-bearing Flutter calls reject plain HTTP. With the PC and phone connected to the authorized tailnet, run in either shell:

```text
tailscale serve --bg --https=443 http://127.0.0.1:5255
tailscale serve status
```

Copy the exact HTTPS MagicDNS origin printed by `tailscale serve status`. It has this shape:

```text
https://YOUR_HOST.YOUR_TAILNET.ts.net
```

Do not commit the real hostname. Do not use `localhost`, a raw Tailscale IP or a LAN address over HTTP for Registration, Login, Refresh, Logout or account access.

Before Flutter testing, open this address in the phone browser:

```text
https://YOUR_HOST.YOUR_TAILNET.ts.net/api/v1/system/info
```

Expected result: the same JSON opens without a certificate warning or bypass.

## 10. Run Flutter on the Connected Phone

Open a third terminal.

### PowerShell

```powershell
Set-Location 'D:\OtherProjects\KK10P-banking-app\banking-lab\mobile\banking_mobile'
flutter pub get
flutter devices
flutter run --dart-define=API_BASE_URL=https://YOUR_HOST.YOUR_TAILNET.ts.net
```

### Command Prompt

```bat
cd /d D:\OtherProjects\KK10P-banking-app\banking-lab\mobile\banking_mobile
flutter pub get
flutter devices
flutter run --dart-define=API_BASE_URL=https://YOUR_HOST.YOUR_TAILNET.ts.net
```

Replace the placeholder with the exact origin from Tailscale Serve. Do not add Markdown brackets or quotes around the URL.

While `flutter run` is active:

| Key | Result | Use in this review |
| --- | --- | --- |
| `r` | Hot reload | Review a Dart visual adjustment while staying on the same screen |
| `R` | Hot restart | Recheck startup routing and saved appearance |
| `d` | Detach | Leave the installed app running while ending the Flutter attachment |
| `q` | Quit | Stop Flutter and return to the shell |

The ASP.NET API remains in its own terminal and is stopped separately with `Ctrl+C` only when testing is finished.

## 11. Produce a True First-Install State

If the installed app has already recorded introduction completion, Welcome correctly will not appear. Use Android Settings > Apps > KK10P Bank > Storage > Clear data for a first-install test.

ADB offers the equivalent command in either shell:

```text
adb shell pm clear com.example.banking_mobile
```

Warning: this deletes only KK10P Bank's local app data on the connected device, including its refresh token and appearance/onboarding preferences. It does not delete PostgreSQL customers, accounts or server sessions. Do not run it if preserving the current phone login is important.

After clearing data, run Flutter again. Hot reload or hot restart alone does not create a first-install state.

## 12. Physical Acceptance Procedure

### A. Welcome and first-install routing

1. Start from cleared app data with the API reachable.
2. Confirm a real startup progress state appears briefly; there must be no fake percentage or timed vault message.
3. Confirm `Welcome to KK10P`, the fake-money limitation and the non-bank statement are visible.
4. Scroll to the bottom and confirm Sign in and Create account are reachable.
5. Select Sign in.
6. Press `R` in the Flutter terminal or close and reopen the app.
7. Confirm the introduction is skipped and Login opens.

Repeat from cleared data with Create account if you want to validate both first choices. Clearing app data is required between those two first-install branches.

### B. Appearance persistence

1. On Welcome, choose Light and inspect the entire screen.
2. Choose Dark and inspect the same hierarchy.
3. Choose System, change the phone's system appearance and confirm the app follows it.
4. Leave one selection active, press `R`, and confirm it remains selected.
5. Confirm switching appearance does not sign in, sign out or navigate to Home.

### C. Login

1. Confirm the only credentials are Email address and Password.
2. Confirm Show/Hide password works and never changes the entered value.
3. Open About this simulator and return using Back.
4. Open API diagnostics and confirm the live API result appears.
5. Open Resend verification; confirm the empty-email validation and generic server response.
6. Press and hold each action once. Raised controls should become inset without a decorative resting border; inset actions should deepen without flashing white or black.
7. Tap safe navigation actions quickly and confirm there is no freeze or stuck pressed state.

### D. Registration and email confirmation

1. Open Create account from a first-install or explicitly signed-out state.
2. Confirm the form contains only Email, Password and optional Display name.
3. Submit empty and invalid values and confirm messages appear outside the field faces without clipping.
4. Submit a new fake identity while Mailpit is running.
5. On the development PC, open `http://localhost:8025` and inspect the captured email.
6. Open the `kk10pbank://auth/verify-email` link on the Android phone, not in the PC browser.
7. Confirm the app asks before sending the one-use token and never displays the token or complete confirmation URL.
8. Confirm success returns to Sign In; reopening the consumed link should produce the safe invalid/used-link behavior.

### E. Session lifecycle and known-account presentation

1. Sign in with a verified fake customer.
2. Confirm protected Home opens only after server authentication.
3. Close and reopen the app; confirm the valid session restores directly to Home without flashing Welcome or Login.
4. Sign out explicitly.
5. Confirm Login appears and Create account is visible again.
6. Confirm Home is no longer reachable through the normal app flow.

Automated tests cover final account rejection, retryable restoration failure, secure-storage-clear uncertainty and stale request protection. Those failure states do not need to be forced manually during the visual review.

### F. Responsive and accessibility pass

Perform the important Welcome, Login, Registration and Verification checks in both Light and Dark.

1. Increase Android font size/display text close to 200%.
2. Open the keyboard on the lowest field.
3. Confirm every error, helper line and action remains scroll-reachable.
4. Confirm no text is clipped, overlapped or reduced to unreadable ellipses.
5. Confirm interactive targets remain comfortable to tap.
6. If TalkBack is used, confirm headings, fields, Show/Hide password and actions are announced in a logical order.
7. Restore the phone's normal font/display settings after testing.

## 13. What to Report From the Phone

For each problem, send:

- screen name and Light/Dark/System mode;
- whether the keyboard or 200% text was active;
- action immediately before the problem;
- resting, pressed, disabled, loading, success or error state;
- screenshot before and during the problem when it concerns depth or press feedback;
- whether it reproduces after `R` hot restart.

A useful report example is: `Login, Dark, 200% text, keyboard open: API diagnostics cannot be reached after password validation; reproduces after hot restart.`

## 14. Automated Verification

From `banking-lab/mobile/banking_mobile`, run in either PowerShell or Command Prompt:

```text
dart format lib test
flutter analyze
flutter test --concurrency=1
```

Verified on 2026-09-08:

- formatting completed;
- `flutter analyze` passed with no issues;
- `flutter test --concurrency=1` passed 149/149;
- widget coverage includes preference defaults/persistence/fail-safe behavior, first-install routing, known-account lifecycle, existing auth journeys, 320/360/412/768 widths and 200% text;
- `git diff --check` passed with only the repository's existing LF-to-CRLF notices;
- `GET /api/v1/system/info` returned the expected Development response;
- no backend, database or API source file changed.

Physical Light/Dark auth acceptance remains pending and must not be represented as automated success.

## 15. Safe Customization Points

Use these centralized areas for bounded visual changes:

- palette, gradients, radii and depth: `lib/core/theme/kk_theme.dart`;
- raised/inset/primary control behavior: `lib/core/ui/kk_embossed_controls.dart`;
- appearance-control composition: `lib/core/ui/kk_appearance_menu_button.dart`;
- screen spacing and hierarchy: the relevant file under `lib/features/.../presentation/screens/`.

After a visual edit, use `r` for a quick comparison, then `R` to verify reconstructed state. Run `flutter analyze` and the complete serialized Flutter suite before accepting the change.

Do not casually customize these security-sensitive boundaries:

- `app_router.dart` protected-route checks;
- `authentication_controller.dart` session lifecycle;
- secure refresh-token storage;
- API origin validation;
- backend authentication, account ownership or database migrations.

Changes to those areas need their own reviewed plan and security tests.

## 16. Troubleshooting

### App remains on the startup logo/progress state

1. Check the API terminal for startup errors.
2. Run the local System Info command from Section 8.
3. Run `tailscale serve status`.
4. Open the HTTPS System Info URL in the phone browser.
5. Press `R` once after connectivity is restored.
6. If only the existing saved session is damaged, use the app's retry path before considering app-data clearing.

### Docker Desktop is open but Login or Registration fails

Run:

```text
docker compose -f banking-lab/infrastructure/compose/compose.dev.yml --profile email ps
```

Docker Desktop and repository containers are separate states. PostgreSQL must report healthy. Registration/resend also requires Mailpit.

### `POSTGRES_PASSWORD` warning appears

The untracked `banking-lab/infrastructure/compose/.env` is missing or is not being resolved. Create/check it using the syntax in Section 7. Do not place the password in a committed file.

### API health works on PC but not on phone

Confirm the phone and PC are on the authorized tailnet, `tailscale serve status` points HTTPS 443 to `http://127.0.0.1:5255`, and Flutter uses the exact printed HTTPS origin.

### Flutter says `API_BASE_URL` is missing or insecure

Quit and rerun Flutter with:

```text
flutter run --dart-define=API_BASE_URL=https://YOUR_HOST.YOUR_TAILNET.ts.net
```

Hot reload cannot change a missing compile-time Dart define.

### Welcome does not appear

This is expected after either first-install path has been selected. Use the explicit app-data clearing procedure in Section 11 only when a fresh-install test is needed.

### Email is not visible

Confirm Mailpit is running, open `http://localhost:8025` on the PC and verify the backend's existing Mailpit user-secrets. Mailpit captures local test messages; it does not deliver to Gmail or another public mailbox.

### Visual change does not appear after hot reload

Use `R` when the edit affects providers, router construction, startup state or theme initialization. Rebuild/reinstall only when changing native Android metadata; Slice 2 does not change native metadata.

## 17. Known Limitations and Deferred Work

- Physical Slice 2 visual acceptance is not yet recorded.
- Home/account recomposition belongs to Slice 3.
- Funding, ledger, transfers, Activity/history and receipts require backend-led later slices.
- Password recovery, PIN, biometrics/passkeys, KYC, notifications, savings and administrator features are not implemented.
- The custom `kk10pbank://` confirmation link is prototype-only; verified Android App Links remain future work.
- Tailscale Serve is private development transport, not production deployment.
- No Flutter preview gallery remains; deterministic state coverage is automated and physical appearance is reviewed in the real app.

## 18. Completion Boundary

Slice 2 may be archived only after Chris confirms the Welcome, Login, Registration and Email Verification surfaces in Light and Dark. Visual corrections must remain within the approved Flutter scope. Any backend, API, database, authentication-method, Home or deferred-feature request returns to a separate plan and approval gate.
