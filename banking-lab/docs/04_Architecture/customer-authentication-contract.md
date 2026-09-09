# Customer Authentication Contract

Status: Implemented and verified locally and on a physical Android phone  
Owner feature: `BL-SEC-005`  
Last verified: 2026-09-05

This is the canonical current contract for the customer registration, verification and session flow. The planning files explain how the work was proposed; this document describes what the repository now does.

## Security Boundary

- Flutter is an untrusted client. The ASP.NET Core API owns identity validation, email confirmation, lockout, session deadlines, token rotation and revocation.
- Credential-bearing endpoints reject plain HTTP. Development phone traffic must reach the API through a trusted HTTPS reverse proxy.
- API responses declare `Cross-Origin-Resource-Policy: same-site`. Secure non-Development/non-Testing responses also declare one-year HSTS; Development deliberately avoids persistent HSTS state on disposable local hosts.
- Forwarded scheme/address headers are accepted only from exact IPv4 or IPv6 loopback proxies, with one forwarded hop. Do not broaden this list to a subnet and do not enable the unsafe forwarded-header environment switch.
- Tailscale Serve is the intended development proxy: tailnet HTTPS terminates at Tailscale and the proxy target stays `http://127.0.0.1:5255`.
- The JWT signing key belongs in .NET user-secrets or a deployment secret store. Access tokens remain memory-only in Flutter; only the rotating refresh token is stored through `flutter_secure_storage`.
- All accounts and balances are fake learning data. This prototype is not a production bank or payment service.

## Endpoint Contract

| Method and route | Authentication | Success | Important failures |
| --- | --- | --- | --- |
| `POST /api/v1/auth/register` | None | `202 Accepted` | `400` validation/insecure transport, `413` oversized body, `429` limited, `503` verification unavailable |
| `POST /api/v1/auth/verify-email` | None; one-use token | `204 No Content` | generic `400` invalid/expired/replayed token, `429`, `503` dependency failure |
| `POST /api/v1/auth/resend-verification` | None | generic `202 Accepted` | `429`, `503` verification unavailable/dependency failure |
| `POST /api/v1/auth/login` | None | `200` access/refresh credentials | generic `401` for unknown, disabled, unconfirmed, locked or invalid credentials; `429`; `503` |
| `POST /api/v1/auth/refresh` | Refresh token | `200` rotated credentials | `400`, `401`, `429` session budget, `503` |
| `POST /api/v1/auth/logout` | Refresh token | `204 No Content` | `400`, `429`, `503`; an unknown well-formed token is still idempotent success |
| `GET /api/v1/auth/me` | Bearer access token plus valid persisted session | `200` with only `id` and nullable `displayName` | `401` invalid/revoked/expired, `503` session lookup failure |

Authentication responses use `Cache-Control: no-store`. Request contracts reject unknown JSON fields, enforce body-size limits and redact secrets from diagnostic string representations. Resend and registration intentionally avoid revealing whether an email already exists.

## Verification Delivery

`SmtpOptions` is provider-neutral. Production-like SMTP must use `StartTls` or `SslOnConnect`; unencrypted SMTP is accepted only for `localhost`, `127.0.0.1` or `::1` so Mailpit can be used safely as a local mailbox.

The confirmation URL is fixed to this app route:

```text
kk10pbank://auth/verify-email?userId=...&token=...
```

The token expires after one hour and is consumed by explicit user confirmation. Reuse is rejected. The custom scheme is acceptable for this local prototype, but a future public release should replace it with a platform-verified Android App Link and an owned HTTPS domain to prevent another app from claiming the scheme.

## Session Lifecycle

```text
App starts
  -> read secure refresh token
  -> none: show Login
  -> present: rotate it once
       -> success: fetch /auth/me and enter Home
       -> 401: erase the rejected token and show Login
       -> temporary failure: keep it for an explicit Retry

Login
  -> backend verifies confirmed/enabled customer
  -> create persisted session and hashed refresh token
  -> save refresh token securely before exposing authenticated UI
  -> keep short-lived access token in memory
  -> fetch minimal current-customer profile

Logout
  -> attempt server family revocation
  -> always clear local credentials
  -> protected routes redirect to Login
```

Every login creates a separate session family. The server enforces 15 days of inactivity, 90 days absolute lifetime, rotation/replay protection and a bounded refresh budget. A valid JWT signature alone is insufficient: protected requests also check the persisted session and current user security state.

## Mobile Routes

| Route | Purpose | Access rule |
| --- | --- | --- |
| `/` | Session restoration gate | Temporary startup route |
| `/login` | Login and verification resend | Redirects authenticated users to `/home` |
| `/register` | Customer signup | Redirects authenticated users to `/home` |
| `/verify-email` | Handles the one-use deep-link values | Available during session restoration |
| `/diagnostics` | Existing System Info connection check | Available while signed out |
| `/home` | Safe display-name greeting and logout | Redirects signed-out users to `/login` |

The protected Home now integrates the [accounts/balances slice](customer-accounts-contract.md): explicit opening and viewing of one zero-balance PHP simulator account. Its code and database-free checks are complete; account migration rollout and phone verification remain pending. Transaction history and fake-money transfers remain future slices.

## Runtime Configuration

Tracked configuration must not contain credentials. Local developer values are stored with .NET user-secrets:

```text
ConnectionStrings:DefaultConnection
Jwt:SigningKey
Smtp:Enabled
Smtp:Host
Smtp:Port
Smtp:Security
Smtp:FromAddress
Smtp:FromName
Smtp:ConfirmationLinkBase
```

The optional Compose `email` profile runs Mailpit on loopback ports `1025` (SMTP) and `8025` (web/API). It is a developer mailbox, not a real email provider. Stop it when unused.

## Verified Phone Boundary and Later Work

- Tailscale Serve HTTPS, Android routing, login, restoration and logout passed on Chris's physical rooted test phone. Rooted-device policy remains a separate demonstration feature; no hidden bypass is introduced here.
- Replace the custom URI scheme before any public/production authentication deployment.
- Add operational email credentials, delivery monitoring, password reset, admin recovery/passkeys and security-event observability in separately reviewed phases.
- Accounts, ledger-backed transfers and transaction history remain outside this authentication contract.

The 2026-09-06 accounts integration adds client session-generation and ordered secure-storage guards so logout, final protected-call rejection and another login invalidate pending account/credential work. AuthenticationController drops visible customer state immediately on logout; secure-storage failure messages report uncertainty. Server session lifetimes, token policy and auth routes remain unchanged. See the accounts contract for bounded protected-call refresh/retry behavior.
