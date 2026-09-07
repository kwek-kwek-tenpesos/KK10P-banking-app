# Task Tracking: KK10P Prototype Adoption Roadmap

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Revision A approved; Slice 1 is implemented and automated checks pass, with physical visual approval pending.
- Target: Selectively rebuild the approved AI Studio/Kotlin prototype direction in the existing Flutter app, then add ledger-backed fake-money funding, transfers and history in separately approved slices.
- Scope Guard: Slice 1 changes only shared Flutter material UI, its isolated proof route and tests. No backend/prototype code, dependency, migration, database row or external repository was changed.

---

## [CURRENT EXECUTION STATE - HANDOFF]

- Active Plan: [KK10P prototype-to-Flutter roadmap](../02_Planning/plan-kk10p-prototype-to-flutter-roadmap.md).
- Design Audit: [KK10P prototype adoption audit](../05_Design/kk10p-prototype-adoption-audit.md).
- Architecture Decision: [Client platform adoption decision](../04_Architecture/client-platform-adoption-decision.md).
- Behavioral Sources: [Authentication](../04_Architecture/customer-authentication-contract.md) and [accounts](../04_Architecture/customer-accounts-contract.md).
- Current Status: Slice 1 now provides shared Light/Dark neumorphic tokens plus a responsive material-proof route reachable from API diagnostics. Existing API/auth behavior remains unchanged and the app stays Light-only outside the proof until appearance preferences are implemented in a later frontend slice.
- Visual Direction: Use the prototype's composition and most of its lighting, normalized into one coherent material: paired top-left light/bottom-right shadow, blue primary/selected states, restrained borders and explicit accessible focus/error states in independently tuned Light and Dark palettes.
- Home Direction: Greeting, simulator disclosure, one PHP account hero, one dominant action, up to three real recent items and bottom-safe navigation. Remove mock alerts, growth, multi-currency/accounts/cards, duplicated quick actions and state selectors.
- Verification Note: `flutter analyze` passed; the complete low-contention Flutter suite passed 130/130; the arm64 debug APK built after stopping the memory-heavy Gradle daemon and retrying. ADB reported no connected device, so physical lighting, press-feel and TalkBack checks remain pending.
- Frontend-First Boundary: Slice 1–3 may implement the design system, first-install/auth flow and current account/Home against existing APIs. PIN and Activity may be documented or debug-previewed, but no release control is enabled before its security/data contract exists.
- Current Blocker: Physical-device visual approval is required before Slice 2 or full-screen restyling; no ADB device was connected during verification.
- Next Immediate Action: Chris opens API diagnostics, taps the palette icon, compares Light/Dark and held-button states, then approves or requests token calibration.
- Superseded: The unapproved Section 15 token-only pass in the earlier mobile UI plan is superseded; it was never implemented.
- Deferred: Funding/ledger, transfers/history, administrator portal, password recovery, PIN/biometrics/passkeys, KYC, notifications, savings, schedules, external rails, Bluetooth and AI guards remain separately gated. Dark mode moved into the revised frontend foundation.

## Active Checklist

- [x] Exclude the mistakenly supplied desktop TikTok/racing note, then read the corrected Banking Lab workspace `temp.txt`.
- [x] Inspect the prototype repository structure, screens, state model, design tokens, dependencies and tests read-only.
- [x] Compare prototype claims with the implemented Flutter/API/account contracts.
- [x] Identify visual, product-truth, navigation, density and engineering inconsistencies.
- [x] Define the keep/simplify/defer/remove matrix and clean Home composition.
- [x] Record the Flutter-first architecture decision.
- [x] Draft the slice-based master roadmap, acceptance criteria, risks and approval gates.
- [x] Mark the earlier unapproved Section 15 plan as superseded.
- [x] Obtain Chris's approval for Flutter/ASP.NET retention, Kotlin-as-design-reference and separate future administrator scope.
- [x] Revise the audit/roadmap for first-install information, Dark/System modes, attached-account visibility and frontend-first sequencing.
- [x] Obtain Chris's confirmation of corrected Revision A.
- [x] Implement and automate-check Slice 1 material proof.
- [ ] Physically approve Slice 1 lighting, contrast and pressed depth.
- [ ] Continue one approved feature slice at a time.

## Planning Verification

- External prototype Git status was clean and remained unchanged.
- Prototype has no `gradlew`/`gradlew.bat`; system Gradle is unavailable. No build result is claimed.
- Static inspection found declared Room, Retrofit, Firebase, OkHttp and Moshi dependencies with no corresponding application-source imports.
- Current Banking Lab routes remain Startup, Login, Register, Verify Email, Diagnostics and Home; current API remains system info, auth/session and one-account endpoints.
- Slice 1 verification: analysis passed, Flutter tests passed 130/130, and the arm64 debug APK built; physical-device review is pending.
