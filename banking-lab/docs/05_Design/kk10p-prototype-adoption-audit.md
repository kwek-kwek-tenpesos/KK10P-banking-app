# KK10P Prototype Adoption Audit

- Status: Flutter/ASP.NET, prototype-reference direction and corrected Revision A approved by Chris. Slice 1 dual-theme material proof is implemented pending physical visual approval.
- Audit date: 2026-09-07.
- Product boundary: Educational, fake-money Banking Lab—not a real bank or payment service.
- Prototype inspected read-only: `D:\OtherProjects\Banking-UI-UX-Prototype`.
- Supporting record inspected read-only: `D:\Download\KK10P_Banking_UI_Master_Implementation.md`.
- Corrected product comments: `D:\OtherProjects\kwek-kwekBank\temp.txt`.
- Related roadmap: [prototype-to-Flutter roadmap](../02_Planning/plan-kk10p-prototype-to-flutter-roadmap.md).
- Current behavioral truth: [customer authentication contract](../04_Architecture/customer-authentication-contract.md) and [customer accounts contract](../04_Architecture/customer-accounts-contract.md).

## 1. Audit Conclusion

The prototype is useful as a visual and interaction reference, but it is not a second banking application that should be converted line by line. It contains approximately 35,582 lines across 90 main Kotlin files, uses local Compose state and large mock-data providers, and has no live Banking Lab API integration. Its completed batches represent clickable client simulations, not completed Banking Lab features.

KK10P should therefore:

1. keep Flutter as the customer client;
2. selectively rebuild approved layouts and reusable visual patterns in Flutter;
3. preserve the existing ASP.NET Core, PostgreSQL, Riverpod, Dio and secure-session architecture;
4. expose only behavior supported by the API;
5. implement fake-money funding, transfers and history as audited backend-led slices before their controls become customer-visible.

The earlier `C:\Users\Admin\Desktop\temp.txt` was the wrong project's TikTok/racing note and remains excluded. The corrected workspace `temp.txt` is Banking Lab input. It confirms Flutter and ASP.NET, authorizes read-only use of the Kotlin prototype as the principal layout/visual model, requests a truthful first-install introduction, requests dark mode in the current frontend phase, identifies PIN/Home/Activity as useful visual references, and confirms that the prototype contains no password or API implementation.

## 2. Evidence Reliability

| Evidence | What it can decide | What it cannot prove |
| --- | --- | --- |
| Supplied phone screenshots | Hierarchy, density, color direction and perceived depth | API behavior, security, accessibility or responsive correctness |
| Kotlin/Compose source | Intended components, mock flows, tokens and navigation concepts | Banking Lab compatibility or production readiness |
| Master implementation Markdown | Feature inventory and author intent | That the repository actually implements secure or connected behavior |
| Prototype tests | Hard-coded model/state consistency and one splash screenshot | End-to-end banking correctness, API contracts or physical accessibility |
| Current Banking Lab contracts/code | Implemented auth, session and single-account behavior | Future funding, ledger, transfer, history or administrator behavior |

The prototype repository has no `gradlew` or `gradlew.bat`, and no system Gradle executable is available. Its documented `compile_applet` and JVM-test claims could not be independently reproduced during this audit. No external repository file was modified.

## 3. Internal Prototype Inconsistencies to Remove

### 3.1 Visual system

- The early design record describes a same-material pale surface, while the latest Batch 12.2 direction uses bright white cards on `#E8EEF6`. This creates the hybrid look Chris previously rejected.
- Some components use raised white surfaces, others use sunken pale surfaces, and others add one-pixel borders even when depth already provides separation.
- Blue and orange both behave as primary actions. KK10P needs one primary action family.
- Almost every control, card and icon receives elevation, so the hierarchy becomes noisy rather than tactile.
- Shadow strength is large enough to look attractive in a static mock but risks blur, crowding and poor edge definition on smaller phones.
- Several screens use oversized headings, pills and buttons simultaneously, leaving too little room for actual banking content.

### 3.2 Product truth

- Splash and Welcome claim hardware encryption, vault protection, instant settlement, no delays, no fees and high-yield savings without supporting implementation.
- Login exposes batch labels, demo credentials, fast-track sign-in, forced error chips, biometric/PIN shortcuts and other evaluator controls to the user.
- Home presents multiple currencies, six accounts, growth percentages, cards and six quick actions despite the current one-account PHP contract.
- Accounts expose US routing numbers, APY, statements, card/wallet types, freezing, restriction and test provisioning without backend authority.
- Transfers simulate P2P, own-account, other-bank, ACH, FedNow, wire, fees and multiple authentication methods without a ledger or transfer API.
- Security, device, notification, support, dispute, KYC and savings screens store or mutate local mock state only.

### 3.3 Navigation and layout

- The mobile bottom bar is overlaid on top of content without reserving equivalent body padding, visibly obscuring Home and Activity rows in the supplied screenshots.
- Home repeats Transfer in the balance card, quick actions and center navigation action.
- Activity displays developer state controls and three full filter rows before showing the first transaction.
- Login places too many optional/recovery/test actions above the account-creation path.
- Splash and Welcome duplicate onboarding decisions.
- Tablet and desktop layouts exist even though the current acceptance target is Android phone plus a limited 768-width resilience check.

### 3.4 Engineering boundaries

- Navigation is a manual enum/state switch rather than the prototype's declared Navigation Compose dependency.
- Room, Retrofit, Moshi, OkHttp, Firebase AI/App Check and KSP dependencies are declared but have no matching imports or usages under `app/src`.
- The manifest has no Internet permission, reinforcing that the prototype is disconnected.
- The application uses a mutable theme singleton and extensive screen-local `remember` state rather than Banking Lab's state and repository boundaries.
- `allowBackup=true` and the mock credential/account data are unsuitable patterns for a security-sensitive client.
- Several source files exceed 700–1,800 lines, so direct translation would import unnecessary complexity and reduce teachability.

## 4. Proposed Coherent Visual Contract

The proposed direction combines the prototype's banking composition with the music-player reference's material behavior.

### Material roles

| Role | Proposed direction |
| --- | --- |
| Light canvas and ordinary face | One cool pale-blue material, initially `#E8EEF6` |
| Inset face | Slightly darker cool material, initially `#DEE6F0` |
| Main text | Deep ink/navy, initially `#0F172A` |
| Secondary text | Slate, initially `#475569` |
| Muted text | `#64748B`, only where contrast remains sufficient |
| Primary action/selection | Solid `#2563EB` with white content |
| Deep blue emphasis | `#1E40AF` for selected text/icons when the background is pale |
| Light source | One soft white upper-left shadow/highlight |
| Contact shadow | One cool blue-gray lower-right shadow |
| Warning/danger | Semantic amber/red only—not an alternate brand CTA |

Dark mode is part of the revised frontend foundation, not a later repaint. It uses separately tuned charcoal/navy material, legible light text, blue actions and paired highlights/shadows; it does not mechanically invert the light palette.

Exact values remain centralized Flutter tokens and may be tuned once on the physical phone. Screens must not introduce local colors or shadows.

### Depth rules

- Raised: one upper-left light plus one lower-right dark shadow; no decorative perimeter border.
- Pressed: transition to an inset basin immediately from the native pressed state.
- Inset: use for editable fields and selected/pressed states; keep explicit focus and validation outlines.
- Flat: use for ordinary copy, metadata, separators and low-priority icon actions.
- Solid blue: use for one primary action per decision region and selected navigation/filter states.
- Semantic status: use text/icon plus a restrained tint; never color alone.

Pure neumorphism means one coherent material and light source, not placing every element on a raised tile. Accessibility boundaries override decorative purity.

### Density rules

- Use a 4-pixel spacing rhythm with 16–20 pixel phone page gutters.
- Keep controls at least 48 logical pixels high.
- Use at most one oversized hero card on Home.
- Use at most three immediately visible Home actions.
- Avoid nested raised cards unless the inner control is independently interactive.
- Reserve bottom safe-area and navigation-bar space in scrollable content.
- Support 320, 360 and 412 logical-pixel widths plus a 768-width resilience layout and 200% text scaling.

## 5. Screen-by-Screen Product Triage

### Startup

Adopt the centered bank mark and calm material depth. Remove the batch banner, unsupported security claims and artificial progress. Startup first checks real session state and a non-sensitive local first-install flag. A logo/progress state appears only while those reads are genuinely pending.

### Welcome

Ship one concise introduction on first install, then make the same information available later from About. It may explain that KK10P uses fake money, requires HTTPS for credential-bearing requests, stores the rotating refresh token in platform secure storage, verifies email and supports revocable sessions. It must also say that KK10P is an educational simulator, not a real financial institution. Remove evaluator fast-track and claims about hardware encryption, instant settlement, yield, biometrics or fraud protection that are not implemented.

The first-install screen offers Sign In and Create Account. Completing either choice records that the introduction was seen. Later launches restore a valid session or go directly to Login rather than replaying onboarding.

### Login

Adopt the strong centered identity, individual fields, blue primary action and generous hierarchy. Retain email-only login because that is the current API contract. Resend Verification remains secondary. Remove demo credentials, batch controls, forced-error chips, PIN, biometric, account-ID/phone identifiers, Remember Me and Forgot Password until each has an approved behavioral contract.

Use a separate non-sensitive local `known account attached` marker. Set it after successful login; preserve it when a session merely expires or restoration fails; clear it only after explicit full Sign Out/removal from this device. Hide Create Account while the marker is present and show it on first install or after that explicit full logout. This marker never authenticates the user and never replaces the secure refresh token.

### Registration and verification

Use the same material and field system while retaining only email, password and optional display name. Do not copy US SSN, address, employment, KYC or terms screens. Keep the implemented one-use email link workflow; do not substitute the prototype's local OTP.

### Home

Use this order:

```text
safe-area top
  greeting + optional backed notification entry
  simulator disclosure
  one PHP account/balance hero
    balance privacy toggle
    Refresh
    Transfer only after the transfer feature is live
  up to three recent transactions only after history is live
    View activity
  contextual single callout only when backed by real state
safe bottom padding above navigation
```

Remove the visible variant selector, default fake security incident, currency selector, growth percentage, six-account count, horizontal account carousel, duplicate quick actions, cards, savings preview, transfer-limit warning and scheduled-payment reminder. Empty/loading/offline/error states stay testable but move to automated tests or debug-only previews.

### Accounts

Present the single PHP simulator account and its UUID reference honestly. Do not label it as a routing/account number. Defer multiple accounts, cards, wallets, APY, interest, statements, freeze/restrict/close and test provisioning. If multiple accounts are later implemented, add the list and filters then—not earlier.

### Transfer

Adopt the step-by-step clarity, amount review, processing and receipt compositions only after backend ledger and transfer contracts exist. MVP transfers should be internal PHP fake-money transfers to another registered simulator account reference. Defer bank rails, fees, other-bank recipients, schedules, beneficiaries, QR, bills, deposits, requests and multi-factor transfer choices.

### Activity

Adopt grouped transaction rows, status badges, search, empty/loading/error states and detail/receipt hierarchy after the API exists. Remove the visible UI-state selector. Start with one compact filter entry that opens direction/status controls; advanced type/date/amount filters come only when data volume justifies them. Body padding must prevent bottom-navigation overlap.

### More/Profile

Initial scope is display name, simulator/account information, diagnostics/about, support information and sign out. Defer avatar uploads, KYC badges, security scores, devices, login-history locations/IPs, language/theme matrices, notification preferences, recovery contacts and emergency freeze until supported.

### Administrator

Do not add administrator screens to the customer Flutter app. A future administrator portal should be a separately planned web surface with backend-enforced roles, audit events and minimal manual simulator operations. It follows the customer MVP and is not part of this adoption pass.

## 6. Keep, Simplify, Defer and Reject Matrix

| Prototype capability | Decision | Reason |
| --- | --- | --- |
| Neumorphic bank identity and blue action language | Keep, normalize | Matches the intended feel when one material/light source is enforced |
| Responsive spacing and scrollable phone layouts | Keep | Required for real devices and accessibility |
| Loading, empty, error and offline states | Keep | Necessary production-quality behavior |
| Splash | Simplify | Real session restoration only |
| First-install introduction | Keep, simplify | One truthful information screen, then skip on later launches and expose through About |
| Email login/register/verification | Keep through existing implementation | Already backed and verified |
| OTP, PIN, biometrics and password recovery | Defer | Require separate security and backend contracts |
| Auth sandbox, batch labels and evaluator shortcuts | Debug-only/remove | Never customer-facing |
| One PHP account and balance | Keep | Current canonical behavior |
| Multiple accounts, currencies and cards | Defer | No current domain/API support |
| Internal fake-money transfer | Add after ledger/funding | Core learning goal |
| Activity/history and receipt | Add after ledger | Core learning goal |
| Demo funding | Add as a separately approved Development-only ledger action | Transfers cannot be tested from permanent zero balances |
| Pay bills, deposit, request, scan QR | Defer | Expands domain and UI without current value |
| ACH/FedNow/wire/other-bank simulation | Reject from MVP | US-specific and disproportionate complexity |
| Beneficiaries and scheduled transfers | Defer | Requires mature transfer model |
| Savings/goals/budgeting/round-ups | Defer | Separate domain after ledger stability |
| Notifications/security incidents | Defer | Requires real event source and delivery model |
| Statements/PDF/share/barcodes | Defer | Requires canonical history and document contracts |
| KYC, devices, security score, FIDO2 | Defer | Security-sensitive; mock controls are misleading |
| Support tickets and disputes | Defer | Requires operations/admin workflow |
| Dark mode | Include in frontend foundation | Explicit corrected requirement; independently tuned and verified rather than auto-inverted |
| Tablet rail/desktop drawer | Defer | Phone-first target; retain adaptive resilience, not full desktop product UI |
| Firebase AI/App Check, Room and Retrofit from prototype | Reject | Existing Flutter/.NET architecture already owns these concerns |

### Prototype asset finding

Most prototype icons are Material `ImageVector` references, not generated files. One 1024-pixel JPEG bank/vault logo and standard launcher assets are present. The JPEG may be used as a visual reference, but a release asset should be cropped/compressed, checked for provenance and preferably replaced by a scalable transparent/vector mark. Until that decision is approved, Flutter's existing replaceable bank icon slot remains the safe implementation choice.

## 7. Home Cleanliness Acceptance Criteria

- [ ] No developer variant selector, batch label or evaluator shortcut appears in a release UI.
- [ ] The first viewport communicates customer identity, simulator status and the one account without unrelated modules.
- [ ] Exactly one primary Home action is visually dominant.
- [ ] Transfer is not duplicated across the hero card, quick actions and navigation.
- [ ] Unsupported currency, growth, multi-account, card, security-event and savings data is absent.
- [ ] Recent activity is limited to three rows plus one View Activity action.
- [ ] Empty/loading/error/offline states replace content rather than stacking above it.
- [ ] Scroll content remains fully visible above the bottom navigation and system navigation area.
- [ ] The layout remains reachable at 320 pixels wide and 200% text without shrinking body text below the design scale.
- [ ] Both light and dark themes preserve the same hierarchy, readable contrast and recognizable material depth.

## 8. Accessibility and Security Guardrails

- Native Flutter controls retain semantics, focus, keyboard and pointer cancellation behavior.
- Focus, error and disabled states use explicit non-shadow indicators.
- Every actionable control has a meaningful label and minimum 48-pixel target.
- Motion respects reduced-animation settings and never delays a banking action.
- Duplicate transfer/funding requests are prevented by controller single-flight behavior and server idempotency, not animation timing.
- Balances and references remain server-authoritative and are never replaced with mock fallback values.
- No real-looking credentials, routing numbers, phone numbers or customer records are copied from the prototype.
- No feature may claim encryption, biometrics, settlement speed, yield, fraud detection or compliance status unless the repository proves it.

## 9. Design Approval Boundary

Chris approved the core Flutter/ASP.NET, selective prototype-reconstruction and separate-administrator direction. Because the corrected note adds first-install state, dark mode and attached-account visibility behavior, this revision must be confirmed before code begins. Confirmation authorizes only the revised frontend slices. It does not authorize database migrations, fake-fund issuance, transfer behavior, administrator access, new dependencies, public deployment or Git writes. Each material backend/database slice requires its own reviewed plan and explicit approval.
