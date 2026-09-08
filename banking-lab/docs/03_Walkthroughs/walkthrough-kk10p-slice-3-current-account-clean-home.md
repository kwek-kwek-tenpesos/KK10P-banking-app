# Walkthrough: Slice 3 Current Account and Clean Home Foundation

- Delivered: 2026-09-08.
- Status: Accepted on 2026-09-08. Automated verification passed 170/170; Chris physically accepted Light/Dark and TalkBack behavior. The optional unopened-customer phone path was not run and remains automated-covered.
- Plan: [Slice 3 Current Account and Clean Home Foundation](../02_Planning/plan-kk10p-slice-3-current-account-clean-home.md).
- Contracts: [customer accounts](../04_Architecture/customer-accounts-contract.md) and [customer authentication](../04_Architecture/customer-authentication-contract.md).

## 1. Delivered Outcome

Authenticated Home now follows the approved pure-neumorphic visual system while remaining truthful to the implemented product. It shows:

- the authenticated customer's display name, with `Customer` as the blank-name fallback;
- a concise educational fake-money disclosure;
- one API-backed PHP simulator account;
- explicit loading, unopened, opening, reconciliation, unconfirmed-opening, loaded and ordinary-error presentation;
- the real formatted balance and wrapping UUID simulator reference;
- a screen-local show/hide balance control;
- working Open, Refresh, Diagnostics and Sign out actions.

The screen intentionally does not copy the prototype's fake combined balance, growth, six accounts, cards, alerts, quick actions, transactions, transfers or inactive bottom navigation. Slice 3 changed no backend endpoint, database object, account contract, package, or material token.

## 2. Concepts Used in This Slice

### API-backed UI state

The interface changes only in response to the existing account controller and repository. It does not display an amount, identifier or success state before the API provides it.

### Single-flight requests

The controller's `_pending` guard allows only one account operation at a time. Rapid Open, Refresh or Retry attempts do not create overlapping client requests; legitimate server rate limiting is still mapped to safe visible feedback.

### Idempotent reconciliation

An interrupted account-opening request may have succeeded on the server even if the phone did not receive the reply. The recovery path therefore performs GET first. It repeats the existing idempotent PUT only after GET confirms no account is present.

### Session-generation stale-result protection

The account controller captures the current authenticated session generation. If logout or another customer login changes that generation, a late account response is discarded instead of appearing in the wrong session.

### Presentation privacy versus authentication

The eye button hides only the displayed balance for the current widget lifetime. It stores no account data and is not authentication, authorization, app locking or transaction step-up.

## 3. Logic Flow

```text
Authenticated Home opens
  -> render greeting and simulator disclosure
  -> AccountController performs GET /api/v1/accounts/me
     -> account exists: Loaded
     -> account_not_opened: Unopened
     -> definitive authentication rejection: invalidate session
     -> temporary/other safe failure: Error + Retry

Unopened -> Open simulator account
  -> Opening (one PUT in flight)
  -> success: Loaded at PHP 0.00
  -> uncertain failure: Account opening unconfirmed

Account opening unconfirmed -> Check account status
  -> Reconciling (GET first)
  -> found: Loaded
  -> confirmed absent: repeat idempotent PUT
  -> still unresolved: remain unconfirmed with safe feedback

Loaded
  -> eye control hides/reveals amount locally
  -> Refresh performs one GET
  -> Sign out remains reachable

Logout/customer change while request is pending
  -> session generation changes
  -> late response is ignored
```

## 4. Changes by Layer

### Flutter presentation

- Rebuilt Home as a calm, scroll-safe single column using the accepted material components and spacing.
- Kept Diagnostics in the app bar and Sign out after the account hero.
- Rebuilt the account card as one raised hero with a flat read-only balance region.
- Added accessible balance privacy and explicit state-specific copy/actions.
- Removed legacy hardcoded light-only text colors from the account card.

### Flutter state

- Added `reconcilingOpen` and `openingUnconfirmed` account statuses.
- Derived retry behavior from the visible state instead of a separate private uncertainty flag.
- Preserved the existing repository call order, single-flight guard, auto-disposal, session invalidation and generation checks.

### Backend and database

- No changes.
- GET `/api/v1/accounts/me` and idempotent PUT `/api/v1/accounts/me` remain authoritative.
- Balances remain permanently zero until a separately approved ledger/funding slice exists.

## 5. Important Repository Paths

| Purpose | Path |
| --- | --- |
| Authenticated Home | `banking-lab/mobile/banking_mobile/lib/features/home/presentation/screens/customer_home_screen.dart` |
| Account hero and privacy UI | `banking-lab/mobile/banking_mobile/lib/features/accounts/presentation/widgets/account_card.dart` |
| Account presentation state | `banking-lab/mobile/banking_mobile/lib/features/accounts/presentation/controllers/account_controller.dart` |
| Account controller tests | `banking-lab/mobile/banking_mobile/test/features/accounts/account_controller_test.dart` |
| Account responsive/widget tests | `banking-lab/mobile/banking_mobile/test/features/accounts/account_card_test.dart` |
| Focused Home tests | `banking-lab/mobile/banking_mobile/test/features/home/customer_home_screen_test.dart` |
| End-to-end Flutter journey tests | `banking-lab/mobile/banking_mobile/test/widget_test.dart` |
| Account behavior contract | `banking-lab/docs/04_Architecture/customer-accounts-contract.md` |
| Canonical mobile design direction | `banking-lab/docs/05_Design/kk10p-mobile-ui-design-system.md` |

## 6. Commands and Syntax

### Format and verify Flutter

```powershell
Set-Location 'D:\OtherProjects\KK10P-banking-app\banking-lab\mobile\banking_mobile'
dart format lib test
flutter analyze
flutter test --concurrency=1
```

Use `--concurrency=1` for the repository's low-contention deterministic suite.

### Start the backend API

Keep this PowerShell terminal open while using the mobile app:

```powershell
Set-Location 'D:\OtherProjects\KK10P-banking-app\banking-lab\backend\Banking.api'
dotnet run --launch-profile http
```

Wait for `Now listening on: http://127.0.0.1:5255`, then verify the API and private proxy from a second PowerShell terminal:

```powershell
Invoke-RestMethod http://127.0.0.1:5255/api/v1/system/info
tailscale serve status
```

If nothing is listening on port `5255`, Tailscale Serve can remain healthy but the phone will still show a server error because its proxy has no API process to contact.

### Run on the connected phone

With the backend terminal still running, confirm the phone is visible:

```powershell
flutter devices
```

Then launch Flutter using the exact HTTPS MagicDNS URL printed by Tailscale Serve:

```powershell
Set-Location 'D:\OtherProjects\KK10P-banking-app\banking-lab\mobile\banking_mobile'
flutter run --dart-define=API_BASE_URL=https://YOUR_HOST.YOUR_TAILNET.ts.net
```

Do not commit the personal tailnet hostname. While `flutter run` is active:

| Key | Action |
| --- | --- |
| `r` | Hot reload after a Dart UI edit |
| `R` | Full hot restart |
| `q` | Stop the Flutter run |

Stopping the backend terminal, pressing `Ctrl+C` in it, closing Codex, or restarting the PC stops the development API. Run the backend startup block again before the next phone session.

## 7. Verification Results

Automated on 2026-09-08:

- `dart format lib test` — completed successfully.
- `flutter analyze` — passed with no issues.
- `flutter test --concurrency=1` — passed 170/170.
- Focused coverage includes both themes; 320, 360, 412 and 768 widths; 200% text; loading/unopened/loaded/error; privacy semantics; opening/reconciliation; duplicate Open/Refresh calls; Diagnostics; sign out; 401 invalidation; and late-result disposal.

Physical result:

- Chris accepted Light/Dark presentation and confirmed TalkBack behavior works on the real phone.
- The optional unopened-customer path was not run; its state/reconciliation coverage remains automated.
- No new APK build was needed because the review used normal hot reload.

## 8. Chris's Physical Verification

1. Log in and confirm the new Home shows only the greeting, simulator disclosure, one account hero, Diagnostics and Sign out.
2. Check the account hero in Light and Dark: top-left light, bottom-right shadow, restrained border, and no inset well behind the read-only balance.
3. Tap the eye twice. Confirm PHP 0.00 becomes `PHP ••••••` and returns without moving the layout.
4. Press and rapidly tap Refresh. Confirm the button remains responsive, no duplicate visual state stacks, and safe rate-limit feedback still appears if the server threshold is reached.
5. Rotate or increase font size. Confirm the display name, account UUID and actions remain readable and scroll-reachable.
6. With TalkBack enabled, traverse from the app bar through greeting, disclosure, account content/action and Sign out. Confirm the eye announces whether the balance is visible or hidden.
7. If practical with an unopened test customer, press Open once and confirm the progress state reaches exactly one PHP 0.00 account.

## 9. Safe Customization Points

- Spacing between Home sections can use existing `KkSpacing` values in `customer_home_screen.dart`.
- Account wording and hierarchy can be adjusted inside `account_card.dart` while preserving truthful state meanings and semantic labels.
- Layout may reuse `KkSoftSurface`, `KkIconTile` and `KkEmbossedButton`; avoid one-off colors/shadows or another theme-token recalibration.
- The amount may be visually resized, but do not parse balance values in the widget or relabel the UUID as a real account number.

Do not change the controller's request ordering, `_pending` guard, session-generation check, repository contract or account-response validation as a visual customization.

## 10. Limitations and Deferred Work

- No simulator funding or nonzero ledger balance yet.
- No transfers, recipient search, transaction confirmation, receipts or history.
- No cards, multiple accounts/currencies, growth, interest, savings, alerts or notifications.
- No functional bottom navigation.
- No biometric/device-credential or app-PIN lock.
- No administrator surface.

For Chris and Gio's future transfer testing, add funds through a separately approved Development-only, authenticated, audited ledger operation. Do not edit PostgreSQL balances directly: transfers need balanced ledger entries, repeatable setup, authorization and audit evidence.

## 11. Next Steps

1. Review and approve the [Slice 4 ledger and Development funding plan](../02_Planning/plan-kk10p-slice-4-ledger-development-funding.md).
2. Implement and verify ledger/funding against database-free and fresh disposable PostgreSQL targets only.
3. Obtain separate approval before migrating shared `banking_lab` or crediting Chris and Gio.
