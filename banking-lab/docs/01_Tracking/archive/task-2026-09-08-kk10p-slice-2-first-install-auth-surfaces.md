# Archived Task: KK10P Slice 2 First-Install and Authentication Surfaces

- Completed: 2026-09-08
- Plan: [Slice 2 first-install, appearance and auth surfaces](../../02_Planning/plan-kk10p-slice-2-first-install-auth-surfaces.md)
- Walkthrough: [Slice 2 delivery walkthrough](../../03_Walkthroughs/walkthrough-kk10p-slice-2-first-install-auth-surfaces.md)
- Boundary: Flutter UI and local non-sensitive experience state only; no backend, API, database, dependency or Kotlin prototype changes

## Delivered

- [x] Added truthful first-install Welcome and reusable About surfaces.
- [x] Added persistent Light/Dark/System appearance selection.
- [x] Coordinated preference loading and secure-session restoration without a fake delay.
- [x] Added versioned introduction and known-account presentation hints that never authorize protected routes.
- [x] Recomposed Login, Registration, Email Verification and Diagnostics using the approved material.
- [x] Preserved email/password login, one-use email verification, rotating refresh-token storage, protected Home and explicit logout semantics.
- [x] Removed prototype-only PIN, biometric, OTP, recovery, evaluator and mock-data controls.
- [x] Removed the Flutter preview gallery in favor of normal physical-device hot reload.
- [x] Updated the roadmap, canonical design, README, changelog, plan and walkthrough.

## Verification

- [x] `dart format lib test` completed.
- [x] `flutter analyze` passed with no issues.
- [x] `flutter test --concurrency=1` passed 149/149.
- [x] Responsive checks covered 320/360/412/768 widths and 200% text.
- [x] `git diff --check` passed with only existing LF-to-CRLF notices.
- [x] Chris confirmed every physical Welcome/auth Light/Dark checklist item passed.
- [x] Chris confirmed the approved material looks correct and behavior works as intended.
- [x] Repeated balance refreshes returned the expected safe too-many-attempts feedback rather than failing silently.

## Deferred

- Slice 3 Home/account layout adoption and Home/account TalkBack review.
- A separately planned local app-lock flow using biometric/device credential or a carefully designed app PIN; this is distinct from the server session and refresh-token lifecycle.
- Funding/ledger, transfers/history, password recovery, KYC, notifications, savings and administrator work.
