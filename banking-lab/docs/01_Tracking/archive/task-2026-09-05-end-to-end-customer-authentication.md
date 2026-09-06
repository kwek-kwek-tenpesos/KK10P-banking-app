# Archived Task: End-to-End Customer Authentication (BL-SEC-005)

Completed: 2026-09-05  
Result: Implemented and verified locally and on Chris's physical Android phone

## Delivered

- [x] Backed up `banking_lab` and applied only `20260904152654_AddCustomerSessions` after exact-target review.
- [x] Configured a private JWT signing key and local loopback Mailpit settings in .NET user-secrets.
- [x] Added provider-neutral SMTP delivery, one-use email confirmation and anti-enumeration resend behavior.
- [x] Added exact-loopback forwarded-header trust for the Tailscale Serve HTTPS boundary.
- [x] Added Flutter login, secure refresh-token persistence, restoration/retry, logout and auth-aware routing.
- [x] Added Android handling for `kk10pbank://auth/verify-email` and a protected customer-home placeholder.
- [x] Verified clean Flutter analysis, 73 Flutter tests, 176 database-free backend tests and six disposable PostgreSQL tests.
- [x] Verified a local real registration-to-revoked-logout journey through Mailpit.
- [x] Enabled Tailscale Serve for the private tailnet and verified HTTPS without certificate bypasses.
- [x] Built, installed and tested KK10P Bank on Infinix X6820, Android 13.
- [x] Verified physical-phone diagnostics, registration, Mailpit capture, Android deep-link delivery, explicit confirmation and login.
- [x] Force-stopped/reopened the app and confirmed secure refresh-token session restoration.
- [x] Signed out, force-stopped/reopened again and confirmed the app remained signed out.

## Physical Verification Evidence

- Tailscale showed the PC and Infinix phone online in the same tailnet.
- Serve exposed the API privately over a valid `https://<host>.<tailnet>.ts.net` URL and proxied only to `http://127.0.0.1:5255`.
- The phone displayed live `Banking API`, `v1.0.0`, `Development` diagnostics.
- Registration displayed the generic anti-enumeration accepted state.
- The fake Mailpit message opened KK10P Bank's confirmation route; no token was printed or recorded in documentation.
- Confirmation displayed `Email verified`; login displayed `Hello, Physical Phone Test`.
- Session restoration survived an Android force-stop; logout prevented restoration after a second force-stop.

## Retained Fake Data

- `codex.e2e.1788620502@example.test`: confirmed local adapter test account.
- `phone.e2e.1788622604@example.test`: confirmed physical-phone test account with revoked signed-out session.

No real credentials or money data were used. No data cleanup, Git staging, commit, push or branch operation was performed.

## Follow-up Boundaries

- The optional ZAP diagnostic scan was not executed. Its preview and 60 offline safety checks passed, and the local immutable image is available; execution still requires separate explicit approval.
- The custom URI scheme is prototype-only. Use a verified HTTPS Android App Link before a public authentication deployment.
- Accounts, balances, transaction history and fake-money transfers remain later MVP slices.
- Admin passkeys/recovery and the Bluetooth simulator remain later work; AI guards remain concept-only.
