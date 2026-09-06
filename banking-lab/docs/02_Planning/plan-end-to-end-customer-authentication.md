# Implementation Plan: End-to-End Customer Authentication

- Date: 2026-09-05
- Status: Approved by Chris on 2026-09-05; implementation in progress.
- Scope: Complete the customer registration, verification, login, session restoration, refresh, protected-home and logout journey before starting accounts or transfers.
- Constraints: Fake identities and fake money only; no paid service; preserve Tailscale settings and System Info; never commit credentials, verification tokens or personal hostnames; keep optional services stopped when unused.

## 1. Why this is the next slice

The repaired backend already owns passwords, lockout, JWT access tokens, rotating refresh tokens, independent session families and protected `/api/v1/auth/me`. The shared `banking_lab` database received `AddCustomerSessions` on 2026-09-05 after a verified backup. The customer journey is still incomplete because verification delivery is intentionally fail-closed, Flutter has no login/session controller, and the physical-phone HTTPS route is not yet trusted and verified.

This slice finishes authentication only. Accounts, balances, history, transfers, admin features, passkeys/Bluetooth and AI-guard concepts remain outside scope.

## 2. Proposed architecture

```text
Flutter registration
    -> HTTPS API registration
    -> ASP.NET Identity creates an unconfirmed user
    -> provider-neutral SMTP delivery sends a one-use confirmation link
    -> customer opens the link in KK10P Bank
    -> Flutter explicitly POSTs the framework confirmation token
    -> backend confirms the email
    -> customer logs in
    -> access token stays in memory; refresh token stays in secure storage
    -> startup/expiry rotates the refresh token and reloads /auth/me
    -> logout revokes the server session and clears local credentials
```

For local-only testing, an optional Mailpit Compose profile supplies SMTP and a test inbox. It must bind to loopback and remain stopped unless email-flow testing is in progress, keeping RAM use low. The SMTP adapter must remain configurable so Chris or Gio can later use a separately reviewed free SMTP account without changing application code. No real credential is stored in tracked files.

For phone traffic, the preferred lightweight route is Tailscale Serve terminating trusted HTTPS and forwarding only to the loopback API listener. ASP.NET may trust forwarded HTTPS metadata only from loopback with a one-proxy limit; LAN or arbitrary callers must not be able to spoof it. Exact Serve configuration waits until Tailscale is connected and its current state can be reviewed.

## 3. Ordered delivery

### A. HTTPS and private runtime configuration

1. Add narrowly scoped forwarded-header handling before authentication guards.
2. Accept forwarded protocol only from loopback and only one proxy hop.
3. Add tests proving a trusted loopback proxy can represent HTTPS and an untrusted client cannot bypass the HTTP rejection.
4. Keep port 5255 as a loopback/backend origin; do not hardcode a personal Tailscale IP or MagicDNS name.
5. Document private `Jwt:SigningKey`, database connection and SMTP settings using placeholders only.
6. Once Tailscale is connected, inspect existing Serve state before configuring a trusted HTTPS origin and test it without disabling certificate validation.

### B. Verification delivery

1. Keep ASP.NET Identity's generated email-confirmation token as the authority; do not invent a short reusable OTP.
2. Add a provider-neutral SMTP adapter behind `ICustomerVerificationDelivery` with bounded timeouts and redacted logging.
3. Add validated SMTP options. Missing/unsafe configuration keeps registration unavailable rather than silently confirming users.
4. Add a bounded, rate-limited HTTPS confirmation endpoint that accepts only user ID and token through an explicit POST.
5. Add a generic resend endpoint so failed delivery or a lost message does not permanently strand an unconfirmed user.
6. Return generic responses where account existence could otherwise be disclosed. Confirmation tokens are single-purpose, expire according to Identity configuration and never appear in logs.
7. Add Mailpit as an optional Compose profile bound to `127.0.0.1`; do not start it during unrelated development.

### C. Flutter customer session

1. Add strict login, token-response and current-customer models matching the existing backend JSON contract.
2. Extend the API service with login, refresh, logout, confirmation and `/auth/me`; apply the existing HTTPS/no-redirect guard to every credential-bearing request.
3. Keep the access token only in memory and the refresh token only in `flutter_secure_storage`.
4. Extend the repository so each successful login/refresh stores the replacement refresh token before the old one is forgotten.
5. Add an application-level Riverpod authentication controller with initializing, signed-out, submitting, signed-in and recoverable-failure states.
6. On startup, try one refresh using the stored token. Clear it only for an authentication rejection; preserve it on a temporary network/server failure so retry remains possible.
7. Add login and confirmation screens, a minimal authenticated home showing the safe display name, and logout. Preserve the existing System Info diagnostic screen.
8. Use `go_router` for signed-out/signed-in redirects without exposing protected content while session restoration is pending.

### D. Verification and documentation

1. Add backend unit/integration tests for delivery configuration, confirmation, resend, proxy trust, generic errors and confirmed-user login.
2. Add Flutter model, service, repository, controller, routing and widget tests, including rotation/storage failure and startup restoration.
3. Run backend tests serially. Run Flutter format, analyze and tests separately to limit RAM use.
4. With PostgreSQL running, perform one fake-user end-to-end test. Start Mailpit only for the email portion.
5. With Tailscale connected, run the final physical-phone HTTPS test; no certificate bypass or cleartext credentials are acceptable.
6. Update README, active tracking, changelog and a delivery walkthrough with only actually verified results.

## 4. Plain-language pseudocode

```text
REGISTER:
    require trusted HTTPS and valid bounded fields
    if verification delivery is not configured: return unavailable
    create unconfirmed Identity user
    generate one-use framework confirmation token
    send confirmation link through configured SMTP
    always return a privacy-preserving accepted message

CONFIRM EMAIL:
    require trusted HTTPS and bounded user-id/token input
    locate the intended unconfirmed user without logging identifiers or token
    ask Identity to consume the confirmation token
    return a safe success or invalid/expired result

LOGIN:
    Flutter validates basic fields and sends them only over HTTPS
    backend applies existing generic credential checks and creates a session
    Flutter stores refresh token in secure storage and access token in memory
    Flutter calls /auth/me and enters the authenticated route

RESTORE SESSION:
    if no stored refresh token: show signed-out routes
    otherwise call refresh once
    if refresh succeeds: securely replace refresh token, call /auth/me, show home
    if token is rejected: clear secure storage and show login
    if network/server temporarily fails: retain token and show retry

REFRESH PROTECTED REQUEST:
    if access token is valid: send protected request
    otherwise allow one shared refresh attempt
    securely store rotated refresh token
    retry the protected request once
    never loop indefinitely

LOGOUT:
    try to revoke the server session using the refresh token
    always clear local access and refresh credentials
    return to signed-out routes
    if server revocation was not confirmed: show a safe warning
```

## 5. Primary affected paths

- `banking-lab/backend/Banking.api/Program.cs` and `Features/Authentication/`: proxy trust, SMTP delivery, confirmation/resend endpoints and option validation.
- `banking-lab/backend/tests/Banking.IntegrationTests/`: verification, proxy and end-to-end backend tests.
- `banking-lab/infrastructure/compose/compose.dev.yml`: optional loopback-only Mailpit profile.
- `banking-lab/mobile/banking_mobile/lib/features/authentication/`, `lib/app/` and `lib/core/storage/`: customer models, API/repository/session state, routing and screens.
- Corresponding Flutter tests under `banking-lab/mobile/banking_mobile/test/`.
- README, task tracking, changelog and a new walkthrough after delivery.

## 6. Acceptance criteria

- [ ] The API refuses missing/invalid signing, database or required SMTP configuration without exposing values.
- [ ] HTTP registration/login/refresh/logout/confirmation remain rejected; trusted loopback proxy metadata works only from the configured proxy boundary.
- [ ] Registration creates an unconfirmed user and sends a one-use confirmation link without disclosing whether an address already exists.
- [ ] Invalid, expired or reused confirmation tokens cannot confirm an account; resend is bounded and privacy-preserving.
- [ ] Unconfirmed users cannot log in; confirmed fake users can log in through the physical app over trusted HTTPS.
- [ ] Access tokens are memory-only; refresh tokens use secure storage and rotate atomically.
- [ ] Startup restoration, transient offline retry, rejected-token cleanup and logout navigation behave predictably.
- [ ] Protected screens do not flash before authentication completes; `/auth/me` remains server-protected.
- [ ] Mailpit is optional, loopback-only and stopped when not needed; no paid service or tracked secret is introduced.
- [ ] Backend and Flutter automated checks pass, followed by a documented fake-user PostgreSQL/Tailscale phone walkthrough.

## 7. Risks and recovery

- Tailscale is currently disconnected on Chris's machine, so exact Serve setup and phone verification are blocked until reconnection.
- A generic SMTP implementation cannot promise that every free provider accepts a message; provider credentials and limits remain operator configuration.
- If delivery fails after user creation, resend is the supported recovery path; never auto-confirm the account.
- If secure storage fails after refresh rotation, the client must fail signed out rather than retain uncertain credentials.
- The shared session migration backup is retained under ignored local storage. Database rollback should restore that verified backup or use a reviewed forward fix; do not run the migration `Down` casually because it deletes session data.
