# KK10P Bank Mobile Experience and UI Design Direction

- Status: Canonical customer-mobile design direction. The dual-theme material and Slice 2 first-install/authentication surfaces are physically approved. Home rollout and Home/account TalkBack review remain later-slice work.
- Product: KK10P Bank educational fake-money prototype and public showcase.
- Audience: Chris, Gio and future contributors.
- Related implementation plan: [mobile UI foundation plan](../02_Planning/plan-kk10p-mobile-ui-foundation.md).
- Proposed successor direction: [prototype adoption audit](kk10p-prototype-adoption-audit.md) and [prototype-to-Flutter roadmap](../02_Planning/plan-kk10p-prototype-to-flutter-roadmap.md). These remain planning references until explicitly approved and implemented.
- Behavioral sources of truth: [customer authentication contract](../04_Architecture/customer-authentication-contract.md) and [customer accounts contract](../04_Architecture/customer-accounts-contract.md).

## 1. What Is Final and What Is Not

The existing Flutter authentication, session and account behavior is real prototype functionality and must be preserved. The current Material 3 screens now form the approved blue-accent neumorphic foundation, while later feature screens will extend the product beyond this initial interface. Mailpit, fake identities, PHP 0.00 balances and local/private hosting remain development simulation boundaries.

The original registration, user-login and admin-login flowcharts under `docs/00_Drafts/assets/authentication-flowcharts/` are idea sketches only. They are not API, security or UI contracts. Their OTP/fingerprint loops must not be implemented literally. Current contracts and approved feature plans take precedence.

The Word document `BL-MOB-002_Flutter_Mobile_Architecture_and_UI_Engineering_Guide_v1.0.docx` remains useful architectural reference material, but its location in `00_Drafts` means it is not the current visual specification. This document is the canonical home for customer-mobile visual decisions.

## 2. Product and Visual Direction

KK10P Bank should feel calm, trustworthy, tactile and clearly identifiable as a simulator. The selected direction is **accessible blue-accent neumorphism**: a pure sculpted-surface visual language with explicit accessibility safeguards.

- use warm-neutral Light and charcoal Dark layered surfaces, generous rounded corners and restrained paired shadows;
- preserve clear labels, borders, focus indicators and contrast instead of relying on shadows alone;
- use blue for focus, selection, important actions and limited decorative emphasis;
- use familiar Material icons consistently;
- create the visual treatment with Flutter widgets, gradients and shadows; no 3D model or artwork is required;
- keep the future logo, illustrations and optional card artwork replaceable without changing screen logic.

Low-contrast, shadow-only controls are not acceptable for form fields, errors, disabled controls or critical actions. Usability and accessibility override decorative depth even though the visual language remains neumorphic.

## 3. Approved Material Tokens

These centralized tokens define the physically calibrated Light/Dark faces, blue action family and shadow strengths. Future adjustments must remain centralized.

| Role | Approved value | Use |
| --- | --- | --- |
| Light canvas | `#ECEDE9` | Warm-neutral main page canvas |
| Light raised face | `#F7F7F3` to `#E5E6E2` | Major surfaces, above their separate shadow backing |
| Light inset face | `#F0F1ED` | Quiet field/selection basin; depth comes from inner lighting |
| Light edge/highlight | `#D9FFFFFF` / `#F2FFFFFF` | Restrained hairline separation and top-left light |
| Light contact shadow | `#809EA3A1` | Neutral lower-right depth |
| Dark canvas | `#22262B` | Independently tuned charcoal canvas |
| Dark raised face | `#2D333B` to `#282D34` | Dark major surfaces |
| Dark inset face | `#2A3037` | Quiet dark field/selection basin |
| Dark surface edge | `#80515A65` | Restrained hairline separation |
| Light primary action | `#2563EB` to `#1E40AF` | High-emphasis filled action |
| Dark primary action | `#60A5FA` to `#2563EB` | High-emphasis filled action tuned for the dark canvas |

Use a consistent spacing rhythm based on 4 logical pixels, with common values of 8, 12, 16, 24 and 32. Interactive controls must remain at least 48 logical pixels high. Radius and shadow values belong in the shared theme rather than individual feature screens.

## 4. Surface and Interaction Rules

- **Base:** background with no elevation.
- **Raised:** paired light and dark shadows for cards and selected containers.
- **Inset:** restrained inner-style treatment for editable fields, selected states and pressed controls; ordinary read-only metrics stay flat unless interaction or hierarchy requires a basin.
- **Pressed/disabled:** visible depth, color and opacity changes; button outlines are reserved for keyboard focus.
- **Focus:** a clearly visible blue outline that does not depend on a shadow.
- **Error:** Material error colors and text remain explicit; never represent failure only through depth or animation.
- **Loading:** preserve progress indicators and disable duplicate actions.

Current controls use compact paired top-left light and bottom-right contact shadows for their resting state. Major panels, ordinary controls and icon tiles use different centralized depth strengths; raised surfaces may use a subtle hairline edge when physical separation needs it. Pressing a raised control swaps its outer depth for paired inner shadows. Login's Create-account and Resend-verification actions remain concave, use blue text/icons, and deepen their inner lighting while pressed. Decorative outlines are not added to ordinary button states; keyboard focus adds an explicit ring. Disabled controls remove misleading raised depth and mute their content. Form fields retain explicit editable, focused and error boundaries.

Ordinary control faces match the pale canvas instead of using a glossy white face. Shared press feedback is 70 ms and begins from the native button's pressed state; release or gesture cancellation restores the resting shape without a forced hold. The component does not globally debounce taps. Sensitive asynchronous actions disable or reject duplicates through their controller's submitting/opening state, while safe local actions remain responsive to separate valid taps. Future transfers require server-side idempotency in their own feature plan; animation timing is not a financial safety control.

Decorative layers must not obscure semantic order, tap targets or state changes.

## 5. Reusable Component Direction

The first implementation should establish only patterns already repeated by current screens:

- shared Light/Dark material tokens;
- soft raised/inset surface container;
- consistent page width, safe-area and scrolling layout;
- shared embossed native buttons, raised form-field surfaces and raised icon tiles;
- reusable loading, error, empty and success panels;
- account summary card using the same surface language.

Do not create future transfer, transaction, profile or administrator widgets before their behavior is planned. New abstractions must have at least two real consumers or remove meaningful duplication.

## 6. Customer Journey and Screen Status

```text
Startup and session restoration
    -> Login or registration
    -> One-use email confirmation
    -> Login
    -> Customer Home
    -> Explicitly open one PHP 0.00 simulator account
    -> View account and refresh balance
    -> Future: recipient -> amount -> review -> step-up -> processing -> receipt
    -> Future: transaction history and detail
```

| Area | Current state | Intended direction |
| --- | --- | --- |
| Startup | Branded progress while restoring preferences and auth | Implemented; real reads only, no fake delay |
| Welcome/About | Truthful first-install explanation and reusable About | Implemented; local completion never authorizes access |
| Login | Email/password form with separated support/info actions | Implemented with existing validation and controller behavior |
| Registration | Email, password and optional display name | Implemented with the same contract and improved hierarchy |
| Email confirmation | One-use link confirmation screen | Implemented with clearer state presentation and no token rendering |
| Home | Greeting, account card, diagnostics and sign-out | Foundation for a future account dashboard |
| Account | Unopened/loading/loaded/error states in Home | Preserve all states; improve hierarchy without inventing funds |
| Transfer | Not implemented | Future planned multi-step flow; no placeholder action yet |
| Activity | Not implemented | Future paginated history and receipt/details |
| Profile/settings | Not implemented | Add only with a separate behavior plan |
| Administrator portal | Not implemented; platform undecided | Separate future product surface with backend-enforced roles |

Navigation must expose only working destinations. A future bottom navigation model may reserve Home, Transfer, Activity and Profile during design, but inactive destinations must not appear in the current app.

## 7. Responsive and Accessibility Requirements

- Support 320, 360 and 412 logical-pixel phone widths and a 768-wide layout.
- Remain usable at 200% text scaling without clipped text or unreachable actions.
- Keep important body text at WCAG-style 4.5:1 contrast where applicable and large text/UI boundaries at least 3:1.
- Use semantic labels and a logical TalkBack traversal order.
- Do not encode loading, success, failure or selection through color alone.
- Respect reduced/disabled animation settings; decorative motion must not block interaction.
- Preserve scrolling for long content, keyboard appearance and landscape constraints.

## 8. Security and Domain Boundaries

Visual redesign must not change authentication, authorization, account ownership, refresh/logout ordering or API contracts. Flutter remains an untrusted client. The backend remains authoritative for identity, permissions, balances and future transfers.

Customer KYC/AML, administrator provisioning, the administrator portal, phone passkeys, device binding, Bluetooth demonstration and AI-guard concept are outside this customer-mobile design slice. The Bluetooth demonstration must never become a banking authentication mechanism.

## 9. Deferred Brand Decisions

- KK10P Bank currently has no logo; keep the icon/logo slot replaceable.
- Use the platform font initially; custom font selection is deferred.
- App-wide Light/Dark/System selection and persistence are implemented through versioned local experience preferences. The choice changes presentation only and never participates in authentication or authorization.
- Illustration and 3D artwork are optional future enhancements, not prerequisites.
- Final administrator-portal platform and its visual system require a separate decision.

## 10. Design Acceptance Boundary

The approved Slice 1 proof establishes one coherent blue-accent tactile material in Light and Dark without changing authentication, account or API behavior. Ordinary controls use compact, role-specific depth and 70 ms native-state feedback; inset treatment is reserved for editable, selected and pressed states. Chris physically approved the material calibration and Slice 2 first-install/authentication surfaces after hot-reload testing on 2026-09-08. The complete Flutter suite passed 149/149. Home layout adoption, Home/account TalkBack, transfers, history, KYC, local biometric/device-credential app lock and the administrator experience remain later work.

## 11. Lighting Reference Refinement

The physical review shows that paired outer shadows alone are not enough to match the selected reference. The refined direction uses one consistent imaginary light source from the top-left:

- top-left edges receive a narrow white highlight;
- the white outer highlight may use a small shared spread so it remains visible on the pale physical display;
- bottom-right edges receive a tighter blue-gray contact shadow plus a softer ambient shadow;
- surface gradients remain subtle and follow the same light direction;
- pressed controls reverse the illusion with clipped inner dark/light shadows;
- depth levels differ by role: icon tile/control, field/action and major card;
- helper/error text is outside the sculpted field body;
- explicit focus, input and error outlines remain above the decorative lighting.

Neumorphism.io and the supplied Uiverse button are parameter references, not dependencies or source-code imports. The Flutter implementation uses centralized tokens, `BoxShadow`, gradients and a focused custom inner-shadow painter. Expensive full-screen blur and shader effects remain excluded for the low-memory Android target.

Chris's separate Jetpack Compose music-player prototype is also design evidence only. KK10P adopts its useful material principle, neutral shadow family and blue role family without copying its Kotlin pointer handler, entertainment layout, artwork, rotary widgets, button density or dependency graph. Native Flutter buttons remain the interaction and accessibility authority.

On the target Android phone, combining the panel gradient and three shadows in one decoration caused the GPU path to tint the entire face blue-gray. Major raised surfaces therefore use a shadow-only backing decoration under a separate opaque gradient face. This is an implementation safeguard, not a second visual style; controls still use the same top-left lighting model.
