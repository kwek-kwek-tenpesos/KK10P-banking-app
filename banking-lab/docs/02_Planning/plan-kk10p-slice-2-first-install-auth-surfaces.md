# Slice 2 Plan: First-Install, Appearance and Existing Auth Surfaces

- Status: Complete. Automated checks and Chris's physical-phone acceptance passed on 2026-09-08.
- Prepared: 2026-09-08.
- Parent roadmap: [KK10P prototype-to-Flutter roadmap](plan-kk10p-prototype-to-flutter-roadmap.md).
- Visual source: [approved mobile design system](../05_Design/kk10p-mobile-ui-design-system.md) and the Kotlin prototype's composition, inspected read-only.
- Behavioral source: [customer authentication contract](../04_Architecture/customer-authentication-contract.md).
- Delivery boundary: Flutter frontend and local non-sensitive experience state only. No ASP.NET endpoint, PostgreSQL schema/data, authentication protocol, dependency or Kotlin prototype file changes.

## 1. Request Understanding

Apply the approved Slice 1 Light/Dark material to the first-install and existing authentication journey. Selectively reuse the prototype's calm crest, centered hierarchy, labeled fields and full-width actions, but remove its fake delays, unsupported security claims, evaluator bypass, OTP/PIN/biometric/password-recovery controls, mock credentials and three-step identity/KYC registration.

Visual calibration uses the normal `flutter run` hot-reload workflow on Chris's connected phone. Automated widget tests remain responsible for deterministic state, responsive and accessibility coverage; no separate preview gallery is retained. This slice does not redesign Home; that remains Slice 3.

## 2. Actors and Goal

| Actor | Goal |
| --- | --- |
| First-install customer | Understand the simulator boundary, choose a path and reach Sign In or Create Account without a fake loading sequence |
| Returning signed-out customer | Reach Login directly, restore a temporarily failed saved session, resend verification or review About information |
| Registered customer | Submit the existing email/password login and reach the protected Home only after server authentication |
| New customer | Submit the existing email/password/optional-display-name registration and continue through the existing email-link verification flow |
| Developer/designer | Adjust truthful Light/Dark auth states through normal Flutter hot reload while automated tests cover deterministic layout and state behavior |

## 3. Confirmed Product Decisions

- Flutter remains the customer app; the Kotlin project is design evidence only.
- ASP.NET Core and PostgreSQL remain authoritative and unchanged in this frontend slice.
- Default appearance for installations with no saved choice is Light, preserving the current app behavior. Light, Dark and System become explicit persistent choices.
- The introduction appears only until the customer chooses Sign In or Create Account. The same content remains reviewable later at `/about` without changing completion state.
- Introduction completion and `known account attached` are local experience hints only. Neither may authenticate, identify a customer, bypass a route guard or replace secure-session checks.
- `known account attached` becomes true after a successful login or successful session restoration. It survives session expiry, final protected-call rejection and temporary restore failure.
- The marker is cleared only when an explicit Sign Out successfully removes local credentials. A secure-storage-clear failure preserves the marker because device detachment is unconfirmed.
- Create Account is hidden on Login while the marker is true. Registration itself remains a public route and server validation remains authoritative.
- Email and password remain the only login credentials. Registration remains email, password and optional display name.
- Resend verification remains secondary. Diagnostics remains visually separate from customer auth actions.

## 4. Prototype Adoption Matrix

| Prototype pattern | Slice 2 decision |
| --- | --- |
| Centered bank crest and concise title/subtitle | Adopt using approved Flutter icon tile and material tokens |
| Scroll-safe single-column phone layout | Adopt through `KkPageBody`, safe areas and keyboard-aware scrolling |
| Full-width primary/secondary action hierarchy | Adopt with `KkEmbossedButton` |
| Labeled concave input fields | Adopt with `KkFieldSurface` and explicit focus/error boundaries |
| Feature-highlight cards | Replace with one compact truthful simulator-information surface |
| Simulated splash progress and cryptographic slogans | Remove; show progress only while real local/session reads are pending |
| Fast-track sign-in, demo credentials and state chips | Remove |
| Phone/account-ID login, Remember Me and Forgot Password | Remove because they are unsupported by the current contract |
| PIN, biometric and OTP shortcuts | Remove; email-link verification remains the implemented method |
| Three-step account/KYC registration | Remove; preserve the current three-field form |

## 5. Proposed Journey and Routing

```text
APP START
  -> concurrently read local experience preferences and restore secure session
  -> while either required read is pending: show truthful Startup progress
  -> authenticated: /home
  -> signed out + introduction incomplete: /welcome
  -> signed out + introduction complete: /login

/welcome
  -> choose appearance (optional; persists immediately)
  -> Sign In: mark introduction complete -> /login
  -> Create Account: mark introduction complete -> /register

/login
  -> submit email/password through existing AuthenticationController
  -> success: mark known account attached -> router sends customer to /home
  -> failure: remain on Login with existing safe error
  -> resend verification in secondary modal/sheet
  -> About -> /about
  -> Diagnostics -> /diagnostics

/register
  -> submit existing three fields through RegistrationController
  -> generic accepted state -> tell customer to check email -> /login

/verify-email?userId&token
  -> confirm the existing one-use link
  -> success/invalid/error states -> /login

EXPLICIT SIGN OUT
  -> revoke server family where possible and clear local credentials
  -> local clear confirmed: clear known-account marker -> /login with Create Account visible
  -> local clear uncertain: preserve marker and show the existing warning
```

Deep-link verification, diagnostics and material proof remain reachable during startup restoration. `/welcome`, `/login` and `/register` redirect authenticated customers to `/home`. `/about` is informational and never affects authentication or introduction completion.

## 6. Screen Composition

### 6.1 Startup

- Center one bank crest, `KK10P Bank` and a progress indicator with the semantic label `Restoring your session and preferences`.
- Display no percentage, fake vault status, security certification or call to action.
- Use no artificial timer; navigation occurs when the real preference/session reads settle.
- On preference-read failure, use safe defaults and continue. Existing retryable session-restore failures surface on Login.

### 6.2 Welcome / About

- Center the bank crest, `Welcome to KK10P` and a short plain-language explanation.
- Use one restrained information surface containing only:
  - educational fake-money simulator;
  - credential traffic requires HTTPS and refresh tokens use platform secure storage;
  - email verification and revocable sessions;
  - not a bank and no real-money payment service.
- Present a labeled Light/Dark/System selector using selected/inset and unselected/raised states.
- First-install mode ends with one blue `Sign in` action and one secondary `Create account` action.
- About mode ends with `Back`; it neither rewrites introduction completion nor shows first-install-only wording.

### 6.3 Login

- Keep a centered crest/title, then a compact form region with visible Email and Password labels.
- Preserve autofill hints, password obscuring, Show/Hide semantics, keyboard submit and controller-owned single-flight behavior.
- Keep one blue `Sign in` primary action.
- Show `Retry saved session` only for the current retryable restore state.
- Show `Create account` only when `known account attached` is false.
- Render `Resend verification` as a secondary inset-accent action.
- Put `About this simulator` and `API diagnostics` in a visually separated developer/information footer, never alongside the primary decision.
- Add one 48-pixel appearance menu button without adding a wide settings row to the form.

### 6.4 Registration

- Keep one scrollable screen, not the prototype's three-step KYC flow.
- Preserve Email, Password and optional Display Name fields, limits, server validation mapping and disabled/submitting behavior.
- Keep helper/error text outside field faces so it does not clip at large text sizes.
- Success remains generic to avoid account enumeration and offers `Return to sign in`.
- Add the same compact appearance menu and back behavior as Login.

### 6.5 Email Verification

- Preserve missing-link, ready-to-confirm, submitting, success and server-error states.
- Keep explicit confirmation before the one-use token is sent.
- Never display or log the token or full confirmation URL.
- Use one primary action per state and return to Sign In after success/invalid link.

### 6.6 Diagnostics

- Preserve the existing real API loading/data/error/retry behavior.
- Keep the material-proof entry developer-facing.
- Add an `About KK10P` entry here so the existing Home -> Diagnostics path also makes the introduction reviewable while signed in; do not mix diagnostic status into the auth form hierarchy.

## 7. Local Data and State Design

Create a dedicated non-sensitive preferences boundary rather than expanding `SecureSessionStore`:

```text
AppPreferencesState:
  status = loading | ready
  appearance = light | dark | system
  introductionCompleted = boolean
  knownAccountAttached = boolean
  warning = optional non-blocking local-read/write message

AppPreferencesStore:
  read snapshot
  save appearance
  mark introduction completed
  mark known account attached
  clear known account attached
```

Use the already installed `flutter_secure_storage` backend through the dedicated preferences provider and namespace. No new package is required, and the existing refresh-token store stays unchanged. Values contain no email, name, customer ID, token or credential. Unknown/corrupt appearance values fall back to Light; malformed booleans fall back to false without blocking startup.

Storage keys are versioned and purpose-specific, for example:

```text
experience.v1.appearance
experience.v1.introduction_completed
experience.v1.known_account_attached
```

The refresh-token key and its ordered access rules remain owned by `SecureSessionStore`.

## 8. Authentication and Security Invariants

- Access tokens remain memory-only; rotating refresh tokens remain in `flutter_secure_storage`.
- No password, token, email, customer ID or display name is written to experience preferences or logs.
- Backend login, lockout, confirmation, session rotation/revocation and account ownership remain unchanged and authoritative.
- The router must use `AuthenticationState.isAuthenticated`, never local experience flags, to protect `/home`.
- Hiding Create Account is an experience choice, not authorization. Direct registration requests still receive all backend validation and limits.
- Session expiry and restore failure clear/reject credentials according to the existing repository contract but do not silently detach the known-account experience marker.
- Explicit logout clears the marker only after local credential deletion is confirmed; remote revocation failure may still detach locally because local credentials were already removed.
- Registration/resend responses remain generic and do not reveal whether an address exists.
- The verification token stays only in the deep-link route parameters needed for the existing request and is never rendered.
- No PIN, biometric, passkey, password reset, OTP, evaluator bypass or hard-coded credential is introduced.

## 9. Affected Files

### New Flutter files

- `mobile/banking_mobile/lib/core/preferences/app_preferences_store.dart`
- `mobile/banking_mobile/lib/core/preferences/app_preferences_provider.dart`
- `mobile/banking_mobile/lib/core/preferences/app_preferences_controller.dart`
- `mobile/banking_mobile/lib/core/ui/kk_appearance_menu_button.dart`
- `mobile/banking_mobile/lib/features/onboarding/presentation/screens/welcome_screen.dart`

### Existing Flutter files to update

- `mobile/banking_mobile/lib/app/app.dart` — bind `ThemeMode` to loaded appearance.
- `mobile/banking_mobile/lib/app/app_router.dart` — coordinate preference/session startup and add `/welcome` and `/about`.
- `mobile/banking_mobile/lib/features/authentication/presentation/controllers/authentication_controller.dart` — update the non-authenticating known-account marker at verified lifecycle points.
- `mobile/banking_mobile/lib/features/authentication/presentation/screens/login_screen.dart` — prototype-inspired clean layout and conditional Create Account.
- `mobile/banking_mobile/lib/features/authentication/presentation/screens/registration_screen.dart` — approved material/layout adoption only.
- `mobile/banking_mobile/lib/features/authentication/presentation/screens/email_verification_screen.dart` — approved material/layout adoption only.
- `mobile/banking_mobile/lib/features/system_info/presentation/screens/system_info_screen.dart` — preserve diagnostics separation and About/material-proof entries.

No backend, migration, API model/service, account/Home or prototype-source file is in scope.

## 10. Planned Tests

### Unit/controller/storage

- Preference defaults, round-trip persistence, corrupt-value fallback and storage failure behavior.
- Appearance change updates state immediately and persists Light/Dark/System.
- Introduction completion changes only after a path is selected.
- Successful login and restore attach the known-account marker.
- Invalid login, registration and resend do not attach it.
- Session expiry/restore failure preserves it.
- Explicit logout clears it after confirmed local credential removal and preserves it on `SessionStorageFailure`.
- Existing refresh rotation, revocation, cancellation and stale-operation tests remain green.

### Router/journey widgets

- First install: Startup -> Welcome -> Sign In and Startup -> Welcome -> Create Account.
- Returning signed-out customer with completed intro: Startup -> Login.
- Stored valid session: Startup -> Home without flashing Login or Welcome.
- Verify-email deep link remains usable during startup reads.
- Authenticated customer cannot stay on Welcome/Login/Register.
- Create Account visibility follows only the known-account marker and never grants access.
- Appearance choice survives app reconstruction and System follows platform brightness.
- Login, registration, verification, resend, diagnostics and retry behaviors remain connected to their current controller/repository calls.

### Responsive/accessibility/manual visual review

- 320, 360 and 412 logical-pixel phone layouts; 768-width resilience check.
- 200% text with keyboard: all fields, errors and actions remain scroll-reachable.
- Minimum 48-pixel touch targets, explicit labels, semantic password toggle and logical traversal order.
- Light/Dark tests cover normal, loading, error, disabled and success states.
- Chris manually reviews Welcome, Login, Registration and Verification in Light/Dark through normal `flutter run` hot reload on the connected phone.

### Quality gates

```text
dart format lib test
flutter analyze
flutter test --concurrency=1
```

APK build/install and physical-device acceptance are a separate post-implementation verification step and require the runtime API define; no private endpoint may be committed.

## 11. Final Pass/Fail Acceptance Criteria

- [x] Given an installation with no saved experience values and no session, when startup reads finish, then Welcome appears with truthful simulator information and no fake delay or unsupported claim.
- [x] Given Welcome, when Sign In or Create Account is chosen, then introduction completion is persisted and the correct existing auth route opens.
- [x] Given a later signed-out launch, when startup completes, then Welcome is skipped and Login opens.
- [x] Given `/about`, when opened later, then the same truthful information is reviewable without changing onboarding state.
- [x] Given Light, Dark or System is selected, when the app is reconstructed, then the choice remains active; invalid storage data safely falls back to Light.
- [x] Given a valid secure session, when the app starts, then protected Home opens without a signed-out-content flash.
- [x] Given no authenticated session, when `/home` is requested, then the router redirects to Login regardless of all local experience flags.
- [x] Given successful login or restoration, then `known account attached` becomes true without storing identity data.
- [x] Given session expiry or temporary restore failure, then the marker remains true and Create Account stays hidden.
- [x] Given explicit Sign Out and confirmed local credential deletion, then the marker clears and Create Account becomes visible; uncertain local deletion preserves it.
- [x] Login accepts only email/password, preserves autofill/password-toggle/keyboard behavior and prevents duplicate in-flight submission.
- [x] Registration preserves exactly email, password and optional display name plus current validation and enumeration-safe success behavior.
- [x] Verification preserves explicit, one-use email-link confirmation and never renders/logs the token.
- [x] Resend verification remains reachable as a secondary action with generic success/error handling.
- [x] No prototype-only PIN, biometric, OTP, password reset, Remember Me, phone/account-ID login, fast track, mock credentials, KYC or state-simulation control appears.
- [x] Diagnostics remains separate from customer auth actions and its loading/data/error/retry behavior remains functional.
- [x] Every auth surface is usable at 320 logical pixels and 200% text with keyboard-safe scrolling and 48-pixel targets.
- [x] Automated widget tests cover key Light/Dark auth states; Chris completed the final visual review through normal Flutter hot reload on the connected phone.
- [x] Existing authentication/session/API contracts are unchanged and all static analysis and Flutter tests pass.
- [x] Chris physically approved both theme modes and core auth states before Slice 2 was archived as complete.

## 12. Out of Scope and Follow-Up

- Home/account layout adoption (Slice 3).
- Ledger, fake funding, transfers, Activity/history and receipts.
- Password recovery, PIN, biometric/passkey/device binding, KYC, notifications and savings.
- Administrator UI, roles or provisioning.
- Backend/API/database changes, production App Links, release signing and public deployment.

Implementation must stop after the approved Slice 2 scope. Any contract or dependency change discovered during implementation returns to planning for explicit approval.

Approval note: Chris approved this Slice 2 plan on 2026-09-08 and removed the proposed Flutter preview gallery in favor of normal `flutter run` hot reload and a concise manual phone checklist. Approval authorizes only the Flutter/local-experience-state files, tests and aligned documentation listed above.

Acceptance note: Chris confirmed on 2026-09-08 that every physical checklist item passed, the theme and auth surfaces worked as intended, and repeated balance refreshes produced the expected safe too-many-attempts feedback. The walkthrough remains the delivered point-in-time guide and was intentionally not expanded further after acceptance.
