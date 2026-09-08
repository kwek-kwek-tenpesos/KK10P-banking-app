# Slice 3 Plan: Current Account and Clean Home Foundation

- Status: Accepted on 2026-09-08. Automated verification passed 170/170; Chris physically accepted Light/Dark and TalkBack behavior. The optional unopened-customer phone path was not run and remains automated-covered.
- Prepared: 2026-09-08.
- Parent roadmap: [KK10P prototype-to-Flutter roadmap](plan-kk10p-prototype-to-flutter-roadmap.md).
- Visual sources: [approved mobile design system](../05_Design/kk10p-mobile-ui-design-system.md), [prototype adoption audit](../05_Design/kk10p-prototype-adoption-audit.md), and the Kotlin prototype inspected read-only.
- Behavioral source: [customer accounts contract](../04_Architecture/customer-accounts-contract.md) and the existing authentication/session implementation.
- Delivery boundary: Flutter Home/account presentation, presentation state, and tests only. No ASP.NET endpoint, PostgreSQL schema/data, migration, authentication protocol, dependency, Kotlin prototype, funding, transfer, Activity, administrator, biometric, device-credential, or app-PIN change.

## 1. Request Understanding

Recompose the authenticated Home screen around the approved pure-neumorphic Light/Dark material and the clean hierarchy of the Kotlin prototype. The screen must remain an honest view of the product that exists today: one customer-owned PHP simulator account, an initial PHP 0.00 balance, its UUID simulator reference, refresh, account opening, diagnostics, and sign out.

The prototype supplies composition and visual hierarchy only. Its fake total balance, growth percentage, multiple accounts, cards, security alert, notifications, quick send, transfers, transaction history, savings goals, bottom navigation, and state-selector controls do not ship in this slice.

## 2. Actors and Goals

| Actor | Goal |
| --- | --- |
| Authenticated customer without an account | Understand the simulator boundary and explicitly open the one supported PHP simulator account |
| Authenticated customer with an account | Read or hide the real API-backed simulator balance, identify the account by its simulator reference, and refresh safely |
| Customer facing a temporary failure | Understand whether a normal read failed or an account opening is unconfirmed, then take the correct retry action |
| Customer signing out | End the current session even if an account request is loading, without late account data returning afterward |
| Developer/designer | Verify every truthful account state in Light/Dark and at supported responsive/text-scale sizes without a separate preview gallery |

## 3. Confirmed Product Decisions

- Flutter remains the customer app; the Kotlin project remains read-only design evidence.
- The accepted Slice 1 material tokens are reused without another global theme recalibration.
- Home shows exactly one PHP simulator account. It does not imply multiple accounts, real bank account numbers, real money, interest, performance, cards, or transaction history.
- The account UUID is labeled `Simulator account reference`; it is never labeled as an account number or routing number.
- The current deterministic `Hello, {display name}` greeting remains. Missing or blank display names fall back to `Customer`.
- A short simulator disclosure precedes the account hero so the page remains truthful without repeating a long warning throughout the layout.
- Read-only balance content is flat inside the raised account hero. Inset treatment remains reserved for selected, pressed, and editable states.
- Balance visibility defaults to visible, matching current behavior. An eye control hides or reveals only the amount for the current widget lifetime; it stores no account data and grants no authorization.
- Diagnostics remains one compact top action. The already implemented Diagnostics -> About path provides signed-in appearance access without adding a second settings row to Home.
- Sign out remains reachable in every account state and continues to use the current authentication controller.
- No bottom navigation appears until its destinations have real approved functionality.
- Local biometric/device-credential or app-PIN locking remains a separate security plan, recommended before money-movement slices but not part of Slice 3.

## 4. Prototype Adoption Matrix

| Prototype pattern | Slice 3 decision |
| --- | --- |
| Safe-area greeting and strong account hero | Adopt with current customer/account data |
| Large total combined balance | Replace with the one real API-backed simulator balance |
| Balance privacy eye | Adopt as local presentation state; default visible |
| Refresh action | Adopt and keep connected to the existing account GET |
| Quick Send and transfer hub | Remove until money movement has an approved backend contract |
| New-login alert and notification badge | Remove; no backing alert/notification data exists |
| Growth percentage and six active accounts | Remove |
| Account/card carousel | Remove; only one simulator account exists |
| Quick-action row | Remove; its destinations are not implemented |
| Recent transactions | Remove until ledger/history is live |
| Fixed bottom navigation | Remove until Home, Accounts, Transfer, Activity, and More destinations are truthful and functional |
| Visible Normal/Skeleton/Empty/Error selectors | Keep in automated tests only; never ship as customer UI |

## 5. Proposed Home Composition

```text
HOME SCAFFOLD
  -> app bar
       KK10P Bank
       one API diagnostics action
  -> scroll-safe centered content
       greeting using authenticated customer display name
       authenticated-session subtitle
       compact fake-money simulator disclosure
       one raised account hero
          icon + Simulator funds label
          state-specific account content
          state-specific primary/secondary action
       full-width secondary Sign out action
       safe bottom spacing
```

The content remains a single column with a maximum readable width. It uses the existing `KkPageBody`, approved spacing tokens, raised surfaces, responsive wrapping, minimum 48-pixel controls, and the same top-left lighting direction in Light and Dark.

### 5.1 Loading

- Show a real indeterminate progress indicator labeled `Loading simulator account`.
- Show concise `Loading your account…` copy.
- Keep Diagnostics and Sign out available.
- Do not render a fake amount, placeholder UUID, skeleton account, or disabled transfer action.

### 5.2 Unopened

- State that no simulator account is open yet.
- Explain that the action opens one PHP simulator account beginning at PHP 0.00.
- Present one blue `Open simulator account` action.
- Disable duplicate submission through the existing controller single-flight guard.

### 5.3 Opening

- Replace the open action with a disabled/progress state labeled `Opening simulator account…`.
- Keep the surrounding hero stable to avoid layout jumps during rapid interaction.
- Do not imply success before the API responds.

### 5.4 Opening Reconciliation

- If opening fails after the request may have reached the server, show a distinct live-region state headed `Account opening unconfirmed`.
- Explain that the app must check account status before trying to open again.
- Use `Check account status` for the recovery action.
- On recovery, show `Checking account status…`; perform the existing GET reconciliation before any repeated PUT.
- If GET finds the account, show Loaded. If GET confirms none exists, the existing idempotent open path may continue. Never create a second account.

### 5.5 Loaded

- Show `Simulator funds`, the API-backed formatted amount, and an accessible show/hide balance control.
- Keep the amount on a flat region within the raised hero; do not use an inset balance well.
- Show `Simulator account reference` and the selectable, wrapping UUID.
- Present one raised `Refresh balance` action connected to the existing GET.
- Preserve visible safe handling for server failures and rate limiting, including the already observed too-many-attempts response.
- Show no fabricated growth, account count, status badge, recent activity, cards, or money-movement action.

### 5.6 Ordinary Read Error

- Show the existing mapped, customer-safe error in a semantic live region.
- Present `Retry loading account` and connect it to the existing read retry.
- Keep this visually and verbally different from `Account opening unconfirmed`.
- Do not expose raw exceptions, endpoints, tokens, or server internals.

## 6. Presentation-State Refinement

The current controller already protects against duplicate calls, reconciles uncertain opens, invalidates rejected sessions, and discards stale results. Slice 3 exposes enough state for truthful copy without changing its API contract:

```text
AccountStatus:
  loading
  unopened
  opening
  reconcilingOpen
  openingUnconfirmed
  loaded
  error

LOAD
  -> loading
  -> GET /api/v1/accounts/me
  -> null: unopened
  -> account: loaded
  -> definitive 401: invalidate current session
  -> other failure: error

OPEN
  -> only allowed from unopened
  -> opening
  -> PUT /api/v1/accounts/me
  -> account: loaded
  -> uncertain failure: openingUnconfirmed

RETRY UNCONFIRMED OPEN
  -> reconcilingOpen
  -> GET first
  -> account found: loaded
  -> no account: repeat the existing idempotent PUT
  -> unresolved failure: openingUnconfirmed

SIGN OUT OR CUSTOMER CHANGE
  -> authentication generation changes
  -> late account results are ignored
  -> auto-disposed account state cannot reappear for another customer
```

The private single-flight flag and session-generation check remain authoritative. No account summary is persisted on the device.

## 7. Security, Privacy, and Data Invariants

- Account ownership remains derived from the authenticated server session; the client sends no customer/account identifier to select an account.
- GET remains read-only and PUT remains idempotent under the existing contract.
- Only `PHP`, zero minor units, a UUID reference, and a valid UTC opening timestamp are accepted by the current model.
- Access tokens remain memory-only and rotating refresh tokens remain in platform secure storage.
- Balance hiding is presentation privacy only. It does not replace reauthentication, authorization, local app lock, or server-side controls.
- No account model, balance, UUID, customer name, token, password, or diagnostic response is added to local preferences or logs.
- Existing no-store, HTTPS, rate-limit, generic-error, session invalidation, and logout-cleanup behavior remains unchanged.
- Rapid taps must not create overlapping controller requests. Server rate limiting remains visible when legitimately reached.

## 8. Responsive and Accessibility Rules

- Support 320, 360, and 412 logical-pixel phone widths, plus a 768-width resilience check.
- Support 200% text without clipped balance text, UUID, state messages, or actions; the full page remains scroll-reachable.
- Long display names wrap safely and do not collide with Diagnostics.
- The UUID uses natural wrapping/selectability rather than shrinking below readable size.
- Every interactive control retains at least a 48-pixel target.
- The privacy control announces both its action and current state, such as `Hide simulator balance, balance visible` and `Show simulator balance, balance hidden`.
- Loading and error changes use semantic labels/live regions without announcing decorative shadows or icons.
- TalkBack order is App bar -> greeting -> disclosure -> account heading/content/action -> Sign out.
- Light/Dark, high text scale, and pressed/disabled states may not depend on color alone.

## 9. Affected Files

### Flutter production files to update

- `mobile/banking_mobile/lib/features/home/presentation/screens/customer_home_screen.dart` — clean Home hierarchy, compact simulator disclosure, responsive greeting, and preserved Diagnostics/Sign out wiring.
- `mobile/banking_mobile/lib/features/accounts/presentation/widgets/account_card.dart` — one-account hero, flat balance presentation, privacy toggle, and explicit state-specific content/actions.
- `mobile/banking_mobile/lib/features/accounts/presentation/controllers/account_controller.dart` — expose opening-unconfirmed and reconciliation progress distinctly while preserving existing request/session behavior.

### Flutter test files to update or add

- `mobile/banking_mobile/test/features/accounts/account_card_test.dart` — state, privacy, semantics, responsive, and theme coverage.
- `mobile/banking_mobile/test/features/accounts/account_controller_test.dart` — explicit unconfirmed/reconciliation transitions plus existing duplicate/stale-result guarantees.
- `mobile/banking_mobile/test/features/home/customer_home_screen_test.dart` — new focused Home composition/navigation/logout/responsiveness coverage.
- `mobile/banking_mobile/test/widget_test.dart` — update only affected end-to-end labels/finders and retain login -> account opening -> loaded -> logout coverage.

### Documentation updated at delivery

- `docs/01_Tracking/task.md` — execution checklist and verification state.
- `docs/03_Walkthroughs/walkthrough-kk10p-slice-3-current-account-clean-home.md` — proportional educational handoff.
- `docs/05_Design/kk10p-mobile-ui-design-system.md` and/or `docs/05_Design/kk10p-prototype-adoption-audit.md` — only if implementation establishes a reusable Home/account rule not already canonical.
- Repository `README.md` and root `CHANGELOG.md` — concise behavior/test status updates when the slice is delivered.

No backend, API service/repository/model, database, migration, package, prototype-source, or preview-gallery file is planned for modification.

## 10. Implementation Sequence

1. Add failing controller tests for ordinary error versus opening-unconfirmed and reconciliation progress.
2. Refine `AccountStatus` and transitions without changing repository calls, single-flight behavior, or session-generation safeguards.
3. Add failing account-card tests for every state, amount privacy semantics, UUID wrapping, and absent unsupported controls.
4. Recompose `AccountCard` using existing material components and approved tokens; do not recalibrate global shadows/colors.
5. Add focused Home tests for greeting fallback, disclosure, diagnostics, sign out, scrolling, and supported sizes.
6. Recompose `CustomerHomeScreen` around the one truthful account hero.
7. Update affected end-to-end widget expectations while preserving auth/account/logout behavior.
8. Format and run targeted tests, static analysis, then the complete serialized Flutter suite.
9. Run the approved `flutter run` physical-device checklist in Light and Dark; Chris performs the human visual/TalkBack review.
10. Record only verified results, write the proportional walkthrough, update canonical docs if needed, and prepare a commit only if Chris explicitly authorizes it.

## 11. Planned Automated Verification

### Controller and behavior

- Initial load reaches unopened, loaded, ordinary error, or session invalidation correctly.
- Duplicate open/refresh/retry taps do not create concurrent requests.
- An uncertain PUT failure reaches `openingUnconfirmed`, not ordinary `error`.
- Recovery visibly enters reconciliation and performs GET before any repeated PUT.
- Reconciliation cannot create more than the one idempotent account.
- Logout/customer generation changes discard late load/open/retry results.
- Existing strict account-response validation remains green.

### Widgets and accessibility

- Loading, unopened, opening, reconciling, opening-unconfirmed, loaded, and ordinary-error states render distinct copy and actions.
- Balance starts visible, toggles hidden/visible, and exposes correct semantics without persisting account data.
- UUID is selectable and does not overflow at supported widths or 200% text.
- Unsupported prototype controls/text are absent.
- Diagnostics navigation and Sign out remain functional in the Home composition.
- Light and Dark widget tests cover key raised, flat, focus, disabled, pressed, and live-region behavior.

### Quality-gate commands

```powershell
Set-Location D:\OtherProjects\KK10P-banking-app\banking-lab\mobile\banking_mobile
dart format lib test
flutter test --concurrency=1 test/features/accounts/account_controller_test.dart test/features/accounts/account_card_test.dart test/features/home/customer_home_screen_test.dart
flutter analyze
flutter test --concurrency=1
```

The implementation walkthrough will also include the exact runtime/API define and phone-launch commands needed for that delivery. It will not claim physical or TalkBack checks until Chris confirms them.

## 12. Manual Physical-Device Checklist

- [ ] Loaded Home in Light has the approved material depth, readable hierarchy, flat balance region, contained button shadows, and no clipped content.
- [ ] Loaded Home in Dark has a visible but restrained raised hero edge, readable balance/reference, and no excessive top-right glow.
- [ ] Press-and-hold Open, Refresh, privacy, Diagnostics, and Sign out controls respond immediately and return cleanly after rapid taps.
- [ ] Balance visibility icon/copy matches the actual visible/hidden state.
- [ ] A long display name and UUID wrap cleanly in portrait and landscape.
- [ ] At the device's large-font setting, every action remains reachable by scrolling.
- [ ] TalkBack reads the screen in the planned order and announces progress/errors once intelligibly.
- [ ] An unopened test customer can open exactly one account and reaches PHP 0.00.
- [ ] Temporary API failure shows safe Retry behavior; an uncertain opening uses `Check account status` rather than an ordinary retry.
- [ ] Repeated refreshes may surface the server's safe too-many-attempts message without freezing, overlapping requests, or exposing internals.
- [ ] Sign out works during a pending account read and late account data does not reappear.

## 13. Final Pass/Fail Acceptance Criteria

- [ ] Given an authenticated customer, when Home renders, then the screen shows only API-backed customer/account information and currently working actions.
- [ ] Given a blank/missing display name, when Home renders, then the greeting uses `Customer` without layout failure.
- [ ] Given no simulator account, when Home loads, then it explains the one PHP account and offers exactly one `Open simulator account` action.
- [ ] Given account opening is pending, when the customer taps rapidly, then only one request is active and the UI shows stable progress.
- [ ] Given account opening becomes uncertain, when failure is displayed, then it is distinguishable from a normal read error and recovery checks account status first.
- [ ] Given an account exists, when Home loads, then it shows the validated PHP balance and wrapping UUID simulator reference without fabricating account/card/transaction data.
- [ ] Given the balance is visible, when the privacy control is activated, then only the amount is obscured and the semantic state/action updates; activating it again restores the amount.
- [ ] Given Refresh is activated, when the request completes or fails, then current data or a safe retryable error appears and duplicate in-flight requests remain blocked.
- [ ] Given a definitive protected-call rejection, when it occurs, then the existing session invalidation flow runs rather than leaving stale account content visible.
- [ ] Given logout or a customer/session generation change during an account request, when a late result arrives, then it is discarded.
- [ ] Given Light or Dark appearance, when Home renders and controls are pressed, then the approved material direction and button behavior remain consistent without new global token changes.
- [ ] Given 320/360/412/768 widths and 200% text, when every account state renders, then no content clips or becomes unreachable.
- [ ] Given TalkBack, when Home is traversed, then the logical order, control labels, progress, privacy state, and error announcements are understandable without relying on color.
- [ ] Given the prototype's unsupported features, when the delivered Home is inspected, then there is no quick send, transfer, transaction, card, savings, notification, fake growth, multiple-account, debug-state selector, or inactive bottom-navigation UI.
- [ ] Given the full Flutter quality gates and Chris's phone checklist, when delivery is reported, then automated and manual results are recorded separately and truthfully.

## 14. Walkthrough Delivery Contract

The Slice 3 walkthrough remains proportional to the delivered change but will include this stable backbone:

1. **Delivered Outcome** — what changed and what the customer can now do.
2. **Concepts Used in This Slice** — at least three accessible concepts, expected to include API-backed UI state, idempotent reconciliation, and session-generation stale-result protection.
3. **Logic Flow** — sequential Home/account state flow without dumping full source files.
4. **Important Repository Paths** — exact production, test, contract, and documentation locations.
5. **Commands and Syntax** — copyable PowerShell commands for format, analyze, tests, API/runtime configuration, Flutter launch, and hot reload where applicable.
6. **Verification Results** — automated results separated from Chris's physical-device/TalkBack results.
7. **Safe Customization Points** — layout/spacing/copy changes that do not alter API, auth, or account invariants.
8. **Limitations and Deferred Work** — no funding, transfer, history, bottom navigation, app lock, or administrator behavior yet.
9. **Next Steps** — the next approved slice/security decision, without silently expanding scope.

## 15. Deferred Work

- Local biometric/device-credential or app-PIN lock and step-up authentication.
- Funding and simulator ledger.
- Transfers, beneficiaries, idempotency keys, receipts, and transfer step-up.
- Transaction Activity/history/search/filtering.
- Multiple currencies, multiple accounts, cards, interest/growth, savings goals, alerts, and notifications.
- Functional bottom navigation and More/Profile information architecture.
- Administrator/audit/operations surfaces.
- Backend/API/database changes of any kind.

## 16. Approval Gate

Chris approved this plan on 2026-09-08. Approval authorizes only the files and behavior described above; it does not authorize deferred security, backend, database, money-movement, Activity, administrator, git commit, or push work.
