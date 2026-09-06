# Delivery Walkthrough: End-to-End Customer Authentication

Delivered: 2026-09-05  
Feature: `BL-SEC-005`  
Status: Implemented and verified locally and on a physical Android phone

## Outcome

KK10P Bank now has a functional local customer journey rather than disconnected registration and token endpoints. A customer can register, receive a real one-use verification message through a provider-neutral SMTP adapter, confirm the account, sign in, restore a rotating session, enter a protected home screen and sign out. The existing diagnostics screen remains reachable while signed out.

The shared `banking_lab` session migration was backed up and applied before this delivery. Local integration created one explicitly fake confirmed account, `codex.e2e.1788620502@example.test`; it was retained for inspection. No real identity, email provider or money data was used.

## Sequential Logic

```text
Register form
  -> validate locally and on API
  -> create disabled-for-login, unconfirmed Identity user
  -> generate one-hour Identity confirmation token
  -> Base64Url encode token into kk10pbank:// deep link
  -> send using SMTP (Mailpit locally)

Verification link
  -> Android opens /verify-email
  -> user explicitly taps Confirm
  -> API decodes and consumes token
  -> replay, malformed, expired or unknown values get one generic failure

Login
  -> API requires HTTPS and confirmed/enabled identity
  -> create persisted 15-day-idle / 90-day-absolute session
  -> return short access token and rotating refresh token
  -> Flutter stores only refresh token securely
  -> Flutter loads /auth/me and router enters /home

Restart or access-token expiry
  -> Flutter reads refresh token
  -> concurrent callers share one rotation request
  -> accepted rotation replaces secure token
  -> rejected token is erased; transient failure remains retryable

Logout
  -> API revokes session family
  -> Flutter clears local credentials even if the network call fails
  -> router returns to /login
```

## Important Concepts

- **Defense in depth:** several independent controls—tailnet access, HTTPS, strict forwarded headers, validation, rate limiting, password hashing, confirmation, short access tokens and persisted session checks—reduce the damage if one control fails.
- **Token rotation:** every accepted refresh exchanges the old secret for a new one. Reuse can indicate theft, so the related session family is revoked instead of trusting both callers.
- **Fail closed:** if the API cannot prove the current session is valid, protected access is denied or returns a dependency error; it does not silently allow the request.
- **Dependency injection:** the registration flow depends on an email-delivery interface. Mailpit and a future SMTP provider can satisfy that interface without embedding provider-specific behavior in registration logic.
- **Protected routing:** `go_router` observes Riverpod authentication state, preventing `/home` from flashing before restoration and redirecting signed-out users away from protected content.

## Main Files and Safe Customization Points

- `banking-lab/backend/Banking.api/Program.cs`: endpoint, authentication, SMTP and proxy registration. Add new protected endpoints with authorization and resource-ownership checks.
- `banking-lab/backend/Banking.api/Features/Authentication/SmtpOptions.cs`: validated provider-neutral delivery settings. Keep secrets outside Git.
- `banking-lab/backend/Banking.api/Features/Authentication/CustomerVerificationDelivery.cs`: creates and sends verification links. Change presentation text here; do not log links or tokens.
- `banking-lab/backend/Banking.api/Features/Authentication/CustomerEmailVerificationService.cs`: confirmation/resend behavior and anti-enumeration responses.
- `banking-lab/backend/Banking.api/Features/Authentication/TrustedLoopbackForwarding.cs`: exact trusted proxy boundary. Do not replace loopback addresses with an entire private subnet.
- `banking-lab/infrastructure/compose/compose.dev.yml`: optional Mailpit `email` profile. It binds only to host loopback.
- `banking-lab/mobile/banking_mobile/lib/app/app_router.dart`: auth-aware route rules.
- `banking-lab/mobile/banking_mobile/lib/features/authentication/data/repositories/authentication_repository.dart`: secure-token lifecycle and rotation deduplication.
- `banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/controllers/authentication_controller.dart`: user-visible auth state transitions.
- `banking-lab/mobile/banking_mobile/lib/features/authentication/presentation/screens/`: login, registration and confirmation UI.
- `banking-lab/mobile/banking_mobile/lib/features/home/presentation/screens/customer_home_screen.dart`: protected placeholder for the later account dashboard.
- `banking-lab/mobile/banking_mobile/android/app/src/main/AndroidManifest.xml`: KK10P Bank custom verification scheme.

The current visual layer uses a simple blue/orange light theme and remains intentionally replaceable. Neumorphic layout, artwork and final screen sketches can be added later without changing the authentication contract.

## Verified Results

- `flutter analyze`: no issues.
- Focused router/UI tests: 2 passed.
- Full Flutter suite, serialized: 73 passed, 0 failed.
- Full backend suite, serialized without the opt-in database variable: 176 passed, 6 explicitly skipped, 0 failed.
- Guarded disposable PostgreSQL session suite: 6 passed, 0 skipped/failed against only `banking_lab_auth_repair_test`.
- Real local Mailpit/API/PostgreSQL journey: registration `202`, unconfirmed login `401`, message captured, confirmation `204`, confirmed login `200`, `/api/v1/auth/me` `200`, logout `204`, post-logout refresh `401`.
- API started from private user-secrets with PostgreSQL stopped, and diagnostic System Info returned `200`.
- Mailpit, API and PostgreSQL were stopped after verification to release memory; no containers were deleted.

An initial manual script requested `/api/v1/customers/me` and correctly received `404`; the canonical route is `/api/v1/auth/me`. Repeating the check with the actual contract returned `200`. This was a verification-script path error, not an app defect.

## Physical-Phone Verification — Passed 2026-09-05

Chris connected the Infinix X6820 (Android 13) over wireless ADB and enabled Tailscale on the PC and phone. Tailscale Serve was enabled with the owner's browser consent and configured in the background on HTTPS port 443, proxying only to `http://127.0.0.1:5255`. The exact private tailnet hostname is intentionally not committed.

The phone build used the exact HTTPS Serve URL as `API_BASE_URL`; no raw Tailscale IP, credential-bearing HTTP or certificate bypass was used. Physical verification passed diagnostics, registration, local Mailpit delivery, custom-scheme handoff to KK10P Bank, explicit confirmation, login and protected home. Android force-stop/relaunch restored the rotating session. Logout followed by a second force-stop/relaunch remained on Login, proving local token removal and server revocation in the user journey.

The API process was stopped after testing. The approved background Serve configuration remains available for future development and points to a stopped loopback target when the API is absent. Disable only that listener with `tailscale serve --https=443 off` if it should no longer persist.

## Known Limits

- The custom `kk10pbank` URI scheme is suitable only for the prototype; a verified HTTPS App Link is required before public authentication use.
- SMTP delivery is configured for local Mailpit, not a production provider. Mailpit must be running when testing registration/resend.
- The tested rooted physical device completed the customer flow; this is compatibility evidence, not root-tamper resistance or device-attestation proof.
- Accounts, balances, transaction history and fake-money transfers are not part of this slice.
- Admin passkeys/recovery and the Bluetooth passkey simulator remain later planned/concept work. AI guards remain concept documentation only and were not implemented.
