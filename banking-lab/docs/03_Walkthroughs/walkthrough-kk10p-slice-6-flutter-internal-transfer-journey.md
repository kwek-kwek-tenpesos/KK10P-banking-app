# Slice 6 Walkthrough: Flutter Internal Transfer Journey

- Date: 2026-09-09.
- Delivery state: Complete. Flutter automation, Gate 6R, Chris↔Gio physical-device transfers, shared-ledger reconciliation, and rapid auto-clicker duplicate suppression passed on 2026-09-10.
- Plan: [Slice 6](../02_Planning/plan-kk10p-slice-6-flutter-internal-transfer-journey.md).
- Contract: [internal transfer](../04_Architecture/internal-transfer-contract.md).

## Delivered outcome

An authenticated customer with an open simulator account can now copy that account reference and enter a protected internal-transfer journey from Home. The flow collects a destination account reference, parses an exact PHP amount without floating point, presents a final review, and displays only server-authored receipt data after success.

The client saves the exact request and UUID idempotency key to secure storage before sending. Rapid taps cannot issue multiple logical requests. If connectivity, timeout, cancellation, an invalid success body, or a server failure leaves the result uncertain, the same request survives route disposal and app restart for safe reconciliation. Secure-storage failure blocks submission instead of weakening recovery.

The Slice 6 code delivery performed no shared migration, balance change, funding action, live transfer, Git operation, Activity/history feature, or theme retuning. Gate 6R later applied only the reviewed constraint migration and still executed no funding or transfer.

## Concepts used in this slice

- **Exact money:** PHP text becomes integer centavos directly; binary floating point is never used.
- **Idempotent recovery:** one logical transfer owns one generated UUID and immutable payload until definitively resolved.
- **Write before send:** recovery data must reach platform secure storage before any money-moving request leaves the phone.
- **Single-flight interaction:** fast repeated confirmation remains visually responsive but invokes one logical submission.
- **Session-safe replay:** one access-token refresh may occur, but it resends the identical envelope.
- **Strict server truth:** malformed, non-PHP, non-UTC, zero-ID, or non-completed receipts are rejected.
- **State isolation:** pending recovery and late-response handling are tied to the authenticated customer/session generation.
- **Progressive disclosure:** Recipient → Amount → Review keeps one primary decision visible at a time.

## Logic flow

```text
Loaded Home account
  -> Copy account reference, or open Transfer funds
  -> Recipient: validate canonical non-zero UUID and reject self
  -> Amount: parse exact PHP centavos and check local bounds/balance
  -> Review: show source, destination, amount and irreversible warning
  -> create UUID idempotency key + immutable request envelope
  -> save envelope to customer-scoped secure storage
  -> POST once with bearer token and Idempotency-Key
       -> one 401 refresh may resend the identical envelope
       -> success: validate receipt, refresh Home account, clear envelope
       -> definitive rejection: clear envelope and return to relevant field
       -> 429: retain envelope for same-key retry or explicit cancellation
       -> uncertain result: retain envelope across navigation/restart
  -> show server-authored receipt or safe recovery action
```

## Important repository paths

| Path | Purpose |
| --- | --- |
| `banking-lab/mobile/banking_mobile/lib/features/transfers/domain/internal_transfer_amount.dart` | Exact PHP parsing, bounds, and formatting. |
| `banking-lab/mobile/banking_mobile/lib/features/transfers/data/` | Strict request/receipt models, secure pending store, HTTPS service, and one-refresh repository. |
| `banking-lab/mobile/banking_mobile/lib/features/transfers/presentation/controllers/internal_transfer_controller.dart` | Transfer state machine, duplicate-tap guard, customer isolation, and uncertainty recovery. |
| `banking-lab/mobile/banking_mobile/lib/features/transfers/presentation/screens/internal_transfer_screen.dart` | Responsive three-step form, recovery states, and immediate receipt. |
| `banking-lab/mobile/banking_mobile/lib/features/accounts/presentation/widgets/account_card.dart` | Home Transfer and Copy account reference entry actions. |
| `banking-lab/mobile/banking_mobile/lib/app/app_router.dart` | Auth-protected `/transfer` route. |
| `banking-lab/mobile/banking_mobile/test/features/transfers/` | Exact-money, API, repository, storage, controller, recovery, responsive, and theme tests. |

## Automated verification

Run from `banking-lab/mobile/banking_mobile` in PowerShell:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter compact
```

Results:

- Flutter analysis: no issues.
- Flutter complete suite: 203 passed, 0 failed.
- Android debug APK: built successfully with a non-routable placeholder HTTPS API value; it was not installed or used for a live submission.
- Transfer coverage includes exact amounts, strict receipts, stable API errors, HTTPS-only requests, identical refresh replay, customer-scoped storage, rapid taps, app recreation, uncertainty, rate limiting, and 320-pixel/200%-text light/dark layouts.
- Ordinary backend regression: 237 passed, 0 failed, 20 opt-in PostgreSQL cases skipped because no database-test variable was enabled.
- Diff whitespace check: passed; line-ending notices are informational only.
- Shared `banking_lab`: not migrated or written during this delivery.

## Start the normal development stack

These commands run the now-migrated Development stack. Keep the first transfer deliberately small and follow the reconciliation checklist below.

From repository root, start the existing containers:

```powershell
docker compose -f .\banking-lab\infrastructure\compose\compose.dev.yml --profile email up -d postgres mailpit
docker compose -f .\banking-lab\infrastructure\compose\compose.dev.yml --profile email ps
```

In a second PowerShell window, start ASP.NET:

```powershell
Set-Location D:\OtherProjects\KK10P-banking-app\banking-lab\backend\Banking.api
dotnet run --launch-profile http
```

In a third PowerShell window, list the connected phone and start Flutter using the already approved private HTTPS host:

```powershell
Set-Location D:\OtherProjects\KK10P-banking-app\banking-lab\mobile\banking_mobile
flutter devices
flutter run -d YOUR_DEVICE_ID --dart-define=API_BASE_URL=https://YOUR-APPROVED-HTTPS-HOST
```

Do not commit the device ID or private host. While Flutter is running, type `r` for hot reload, `R` for hot restart, and `q` to stop it.

## Completed pre-Gate phone checks

Before Gate 6R, the safe checks were:

1. Sign in and confirm Home loads the current simulator balance.
2. Confirm `Copy account reference` copies the exact visible reference and announces success.
3. Open `Transfer funds` and move through Recipient, Amount, and Review using validation-only values.
4. Verify blank, malformed, all-zero, and self references remain blocked.
5. Verify PHP 0.00 and PHP 50,000.01 remain blocked; do not press final confirmation for a valid request.
6. Check light/dark mode, Back behavior, keyboard reachability, 200% text, and TalkBack wording.

## Gate 6R: completed

Gate 6R completed on 2026-09-10. It performed a read-only preflight, fresh verified backup, API quiescence, exact `20260909065721_AddInternalTransfers` application, postflight reconciliation, API restart, and read-only HTTP 200 health check. See the [Gate 6R migration safety report](walkthrough-kk10p-gate-6r-shared-transfer-rollout.md).

The migration has a special rollback rule: after any internal-transfer ledger row exists, do not run its Down migration because the funding-only constraint can no longer represent that data. Recovery would require a separately reviewed data plan.

## Post-Gate manual checklist

After Gate 6R succeeds:

1. Exchange Chris and Gio account references privately; do not paste them into logs or tracked files.
2. Send a deliberately small fake-PHP amount and rapidly tap Confirm.
3. Verify one completion receipt, one sender debit, one recipient credit, and exact combined-balance conservation.
4. Refresh both Home screens. Activity/history is intentionally absent until Slice 7.
5. At an agreed safe point, interrupt connectivity, restore it, choose the same-request recovery action, and confirm no duplicate debit.
6. Capture any unclear TalkBack order, clipping, keyboard obstruction, or misleading success/error wording.

## Completed real-device acceptance

Chris and Gio confirmed the ordinary transfer journey, receipt, sender debit, recipient credit, and refreshed Home balances on physical devices. The final duplicate-submission check first used manual rapid tapping and then an auto-clicker. The auto-clicker attempt produced one PHP 1.00 movement.

A read-only PostgreSQL reconciliation found four intentional internal transfers—PHP 12,000.00 and three separate PHP 1.00 transfers—with four distinct idempotency keys. Every transaction has exactly two postings with a zero sum, no malformed transaction exists, and the combined customer balance remains PHP 200,000.00.

This closes the real-device Slice 6 acceptance boundary. Interrupted-connectivity same-key recovery remains covered by automated tests rather than a deliberately induced shared-device outage. Activity/history remains deferred to Slice 7.

## Deferred work

- Slice 7: authenticated Activity/history, pagination, transaction detail, and historical receipts.
- Slice 8: broader customer navigation and final Home integration.
- Later security slice: restored-session PIN/biometric app lock and step-up policy, if approved.
- Future separate work: admin portal, Cloudflare Tunnel, external rails, beneficiaries, schedules, fees, disputes, and production hardening.
