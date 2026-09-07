# Implementation Plan: KK10P Mobile UI Foundation

- Status: Section 14 bank-restrained material and rapid-interaction calibration is implemented and passed automated, build and agent device gates. Chris visual acceptance and Home/account TalkBack remain pending.
- Scope mode: Visual-system foundation and restyling of existing customer screens without behavior changes.
- Canonical design direction: [KK10P mobile experience and UI design](../05_Design/kk10p-mobile-ui-design-system.md).
- Execution note: Chris explicitly moved the untested Home/account TalkBack check into the post-redesign review and authorized implementation to proceed.

## 1. Request and Goal

Establish an accessible blue-accent neumorphic Flutter design system and apply it to the screens that already work: startup, login, registration, email confirmation, diagnostics, customer Home and the account card. The goal is to prevent future transfer and history screens from extending temporary one-off styling.

This is a visual refactor. Existing API requests, route protection, registration fields, authentication/session behavior, account ownership and account-opening behavior must remain unchanged.

## 2. Actors and User Value

- **Guest:** sees coherent login, registration, resend and email-confirmation experiences.
- **Authenticated customer:** sees a coherent Home and account experience without losing any loading, unopened, opening, loaded, failure, retry or logout behavior.
- **Contributor:** can build future customer screens from centralized tokens and a small reusable component set.

## 3. Confirmed Requirements

- Keep the existing pale-blue, blue/navy and orange palette as the starting point.
- Use hybrid neumorphism: soft paired shadows and rounded surfaces with explicit contrast, focus and state indicators.
- Keep the app name `KK10P Bank`; use the existing Material bank icon until a logo is provided.
- Keep artwork and logo slots replaceable. No 3D assets or new UI package are required.
- Expose no unfinished transfer, history, profile or admin destination.
- Preserve 320/360/412/768 layout support, 200% text scaling, 48-pixel actions and TalkBack semantics.
- Preserve current Material loading, error, validation, disabled and success behavior where it provides clearer accessibility than decorative styling.

## 4. Explicit Non-Goals

- No backend, endpoint, database, migration, authentication-policy or account-contract change.
- No transfer, ledger, transaction-history, funding, KYC or administrator implementation.
- No phone passkey, biometric, Bluetooth, device-integrity or AI-guard work.
- No dark theme, custom font, custom icon pack, animation package or production branding package.
- No screenshot-only mock controls that imply unavailable functionality.

## 5. Affected Areas and Planned Files

| Path | Planned change |
| --- | --- |
| `mobile/banking_mobile/lib/core/theme/kk_theme.dart` | New centralized colors, typography, shape, button/input themes and reusable depth tokens. |
| `mobile/banking_mobile/lib/core/ui/kk_soft_surface.dart` | New reusable raised/inset surface with bounded, accessible variants. |
| `mobile/banking_mobile/lib/core/ui/kk_status_panel.dart` | New shared loading/error/success panel only if at least two current screens use it cleanly. |
| `mobile/banking_mobile/lib/app/app.dart` | Replace inline one-off theme construction with the centralized KK10P theme. |
| `mobile/banking_mobile/lib/app/app_router.dart` | Style the startup state only; do not alter routes or redirects. |
| `mobile/banking_mobile/lib/features/authentication/presentation/screens/login_screen.dart` | Apply shared layout, surface, field and action styles without changing commands. |
| `mobile/banking_mobile/lib/features/authentication/presentation/screens/registration_screen.dart` | Apply the same auth layout and preserve every validation/success state. |
| `mobile/banking_mobile/lib/features/authentication/presentation/screens/email_verification_screen.dart` | Align confirmation, invalid-link, loading, success and failure presentation. |
| `mobile/banking_mobile/lib/features/home/presentation/screens/customer_home_screen.dart` | Establish the customer dashboard shell using only currently available actions. |
| `mobile/banking_mobile/lib/features/accounts/presentation/widgets/account_card.dart` | Convert the account card to shared tokens/surfaces while preserving every state. |
| `mobile/banking_mobile/lib/features/system_info/presentation/screens/system_info_screen.dart` | Lightly align developer diagnostics while keeping it clearly secondary. |
| Existing/new tests under `mobile/banking_mobile/test/` | Verify components, state visibility, semantics, responsiveness and regressions. |
| README, active task, walkthrough and changelog | Record implementation and verified results only after delivery. |

If inspection during implementation shows that a proposed shared widget has only one consumer or creates a complicated API, keep the styling in the closest existing widget and record the simplification.

## 6. Plain-Language Implementation Sequence

1. Capture the current behavioral and visual baseline
   - Run Flutter analysis and tests before modifying UI code.
   - Record existing routes, actions, states, field labels and semantics that must not change.
2. Centralize theme tokens
   - Move the approved palette, spacing, radius, text hierarchy and component themes into `kk_theme.dart`.
   - Define restrained paired-shadow values for raised and pressed/inset surfaces.
   - Keep error/success colors semantic and contrast-safe.
3. Add the smallest reusable surface components
   - Build a soft-surface widget with raised and inset variants.
   - Reuse Flutter button and input theming rather than wrapping every control.
   - Add a shared status panel only if current duplication justifies it.
4. Restyle authentication screens
   - Apply the shared page width, scroll behavior, spacing and surface hierarchy.
   - Preserve registration fields, resend dialog, one-use email confirmation and all controller calls.
5. Restyle Home and account states
   - Apply the dashboard shell and account-card depth treatment.
   - Keep unopened, opening, loading, loaded, error, Retry, Refresh and Sign out actions unchanged.
   - Do not display invented balances, history, cards or transfer shortcuts.
6. Align startup and diagnostics
   - Give startup a lightweight branded state without artificial delay.
   - Keep diagnostics visibly separate from customer banking content.
7. Add and update tests
   - Test shared components and all existing states.
   - Test small widths, 768 width, 200% text, keyboard-safe scrolling, semantics, focus and minimum action size.
   - Re-run authentication, routing and account regression suites.
8. Perform physical review
   - Compare login, registration and Home on the connected Android phone.
   - Listen through the primary screens with TalkBack and confirm traversal/control announcements.
   - Tune centralized shadow strength only if the physical display makes boundaries unclear.
9. Document delivery
   - Update task state, walkthrough, README and the top changelog entry with commands actually run and remaining limitations.

## 7. Behavioral Pseudocode

```text
WHEN the app starts:
    apply one centralized KK10P light theme
    restore authentication exactly as today
    show the existing route selected by authentication state

FOR each existing screen:
    render a safe, scrollable page shell
    render current data/state through shared surfaces and semantic colors
    connect buttons to the same existing controller commands
    never create data or navigate to an unfinished feature from decoration

WHEN state is loading or submitting:
    show a progress announcement
    disable duplicate action

WHEN state is an error:
    show explicit error text and the existing safe retry action
    do not communicate failure through shadow or color alone

WHEN text scale or width changes:
    wrap content and allow scrolling
    keep every required action reachable
```

## 8. Acceptance Criteria

- [x] The centralized theme supplies the approved palette, typography, shapes, input/button styles and depth values; target screens do not introduce new one-off brand colors or arbitrary shadows.
- [x] Login, registration, resend, email confirmation, session restoration, diagnostics, account opening/refresh/retry and logout retain the same controller/API actions, covered by regression tests.
- [ ] Startup, auth screens, Home and account states look recognizably like one KK10P product using restrained hybrid-neumorphic surfaces. Physical review found panels coherent but controls and hierarchy materially flatter than the approved concept.
- [x] Text, focus, input and button boundaries have explicit borders/contrast and do not rely on shadows alone.
- [x] No unfinished route or control for transfers, history, profile, KYC or administration appears.
- [x] Loading, empty/unopened, opening, loaded, validation, success, server-error, offline and retry states remain visible and testable.
- [x] Layout tests pass at 320, 360, 412 and 768 logical pixels and at 200% text scaling without overflow or unreachable account actions.
- [x] Interactive controls retain at least 48 logical-pixel targets and useful semantics in automated checks; human Home/account TalkBack order remains pending.
- [x] No password, token, customer identifier or other sensitive value was added to logs, screenshots or decorative widgets.
- [x] `dart format`, `flutter analyze` and the 117-test full Flutter suite passed after the second visual correction in low-memory mode; physical results remain separate.
- [x] No backend file, migration or shared database was changed by this slice.

## 9. Risks and Recovery

- **Low contrast:** neumorphic boundaries can disappear on some screens. Keep explicit focus/input/error treatment and tune centralized shadows using physical-device evidence.
- **Over-abstraction:** too many visual wrappers can make Flutter code harder to learn. Add only components with repeated real use.
- **Behavior regression:** restyling may accidentally drop a state or command. Preserve controller calls and assert each state in widget tests.
- **Overflow:** large text and long account references can break decorative layouts. Use flexible wrapping and scrolling before shrinking text.
- **Recovery:** because the change is frontend-only, revert the affected presentation/theme changes while retaining backend/database state. Do not reset shared data.

## 10. Implementation Approval Gate

Chris approved this feature-specific plan on 2026-09-06 and then explicitly authorized implementation while carrying the untested Home/account TalkBack check into post-redesign review. The initial implementation and automated gates completed on 2026-09-07, and the debug APK built with the existing private HTTPS define. Physical screenshots confirmed behavior but exposed the visual gap detailed below. Database and Mailpit are not required for the correction or widget tests.

## 11. Visual-Fidelity Correction Amendment

### Evidence and Diagnosis

The generated Login/Home concept remains the visual target, interpreted as a responsive design rather than pixel-identical artwork. Chris's physical screenshots confirm that the shared large panels have soft depth, but several controls still use flat Material presentation:

- the orange primary actions have color and radius but no tactile raised/pressed treatment;
- login and registration fields use explicit outlines inside one large raised container instead of individual soft-depth field surfaces;
- Login lacks the concept's `Welcome back` hierarchy, icon-led secondary actions, divider and separate raised diagnostics tile;
- Home places the greeting in a flat bordered panel while the concept uses a plain greeting and a raised wallet icon tile inside the account surface;
- Refresh is an ordinary outlined button rather than the concept's raised secondary action;
- diagnostics and verification inherit the correct palette but not the stronger embossed action hierarchy.

Images 1–5 use the normal phone font size and are the visual-fidelity evidence. Image 6 alone uses extra-large text and is the accessibility wrapping evidence. The normal-scale images will be compared with the concept's proportions; the extra-large case may intentionally wrap differently while remaining readable and reachable.

### Approved-Behavior Invariants

- Keep every route, controller call, API request, account state, error state and permission boundary unchanged.
- Keep explicit input/focus/error borders; depth cannot be the only affordance.
- Keep at least 48 logical-pixel targets, keyboard access, TalkBack labels and scroll reachability.
- Do not add a UI package, logo asset, fake balance/card, animation dependency or unfinished destination.

### Planned Changes

1. Extend the shared depth tokens with visible resting, pressed/focused and disabled treatments.
2. Add one reusable embossed control frame that retains real Material button semantics, keyboard focus and test finders.
3. Add one reusable field surface/focus treatment only if it cleanly supports all current auth fields; otherwise extend the shared input theme.
4. Recompose Login closer to the reference: bank mark, `Welcome back`, individually layered fields, embossed primary action, icon-led account/resend actions, divider and separate diagnostics surface.
5. Recompose Home closer to the reference: greeting outside a card, raised wallet icon tile, stronger account surface and embossed Refresh action. Keep the diagnostics action truthful rather than disguising it as a bank-logo button.
6. Apply the same control-depth rules to registration, verification and diagnostics without changing their information or state flow.
7. Test normal and 200% text at 320/360/412/768 widths, pressed/disabled/focus states, password semantics and all existing regressions in low-memory mode.
8. Rebuild and compare on the phone at normal text first, then large text. Perform TalkBack after visual acceptance.

### Plain Pseudocode

```text
FOR each interactive control:
    keep the native Flutter control and its callback
    draw a shared light highlight and blue-gray depth shadow around it
    WHEN pressed or focused:
        animate to a shallower/inset treatment
        retain an explicit focus or input border
    WHEN disabled:
        remove misleading depth and reduce contrast without hiding the label

ON Login:
    show bank identity and Welcome back hierarchy
    show each credential field as its own tactile control
    show Sign in as the strongest embossed orange action
    show account/resend as secondary icon actions
    separate diagnostics into its own soft action surface

ON Home:
    show greeting directly in the page hierarchy
    show wallet icon in a small raised tile inside the account surface
    show Refresh as a raised secondary action
    preserve account content, diagnostics and Sign out behavior
```

### Correction Acceptance Criteria

- [ ] At normal text scale, Login and Home visually follow the generated concept's hierarchy and depth without requiring pixel-identical artwork.
- [ ] Primary buttons, secondary raised actions, field surfaces and icon tiles visibly read as tactile/embossed on the physical phone.
- [x] Pressed, focused and disabled controls have distinct states and never rely on shadow alone.
- [x] Registration, verification and diagnostics reuse the same depth rules rather than introducing one-off shadows.
- [x] At 200% text, automated layout checks keep labels, fields and actions readable and reachable by scrolling; physical confirmation remains part of the comparison.
- [x] Existing functional and security behavior remains unchanged and the 112-test low-memory Flutter suite passes.
- [ ] Chris accepts the normal-scale physical comparison before the visual gate is closed; Home/account TalkBack is verified afterward.

### Approval Gate

Chris explicitly approved this amendment on 2026-09-07. No backend, database, migration, private endpoint or shared customer data change is required.

### Correction Implementation Result

The implementation adds shared `KkEmbossedButton`, `KkFieldSurface` and `KkIconTile` components backed by centralized depth tokens. The native Flutter buttons and text fields remain in the widget tree, preserving callbacks, focus, semantics and existing test finders. Login, registration, verification, diagnostics and account actions reuse those components; Home and Login were recomposed without changing route or controller behavior.

`flutter analyze`, 34 correction-focused tests and the complete 112-test low-memory suite passed. The debug APK also built successfully with the active private HTTPS runtime define without persisting it. Loopback and private diagnostics returned HTTP 200 after the API was restarted; corrected physical comparison remains the open acceptance gate.

## 12. Proposed Lighting and True-Inset Fidelity Amendment

### New Physical Evidence

Chris's normal-font screenshots confirm that the first correction preserved Login, diagnostics, registration, keyboard scrolling and authenticated Home/account behavior. They also show why the visual gate remains open:

- paired outer shadows are present but the light edge is too weak and the dark shadow is too diffuse to produce the reference's sculpted bevel;
- orange actions are solid fills with an outer shadow rather than a subtly graded, highlighted raised surface;
- the pressed state only becomes shallower; it does not invert to the CSS references' concave/inset lighting;
- `KkFieldSurface` surrounds the entire Flutter field, including helper/error height, which creates a protruding shelf below registration fields;
- Sign out still uses the flat outlined treatment and breaks the tactile control hierarchy;
- major surfaces have similar elevation, so icon tiles, fields, cards and actions do not communicate distinct depth levels.

### Reference Interpretation

The Neumorphism generator varies background color, size, radius, shadow distance, intensity, blur, shape and light direction. The supplied Uiverse example uses the essential formula: matching surface/background color plus one dark bottom-right and one light top-left shadow, then swaps both shadows to `inset` when pressed. These are two-dimensional lighting effects, not 3D models.

The implementation will translate the visual system rather than copy third-party CSS. Flutter's standard `BoxShadow` remains suitable for raised outer shadows and gradients for a mild bevel, while a small native `CustomPainter` is required for clipped inner shadows. No UI package, external asset or third-party source file is required.

### Planned Changes

1. Add centralized light-source, depth, blur and surface-gradient tokens with restrained levels for small controls, fields and large cards.
2. Add a reusable native inner-shadow painter clipped to the component radius; use it only for pressed controls and optionally focused fields.
3. Change tactile controls from flat fills to subtle top-left-to-bottom-right gradients with a narrow highlight edge and a tighter contact shadow.
4. Correct field composition so helper and error text render outside the raised input body while remaining associated with the native input semantics.
5. Move Sign out onto the shared secondary tactile control and keep diagnostics visually secondary.
6. Preserve explicit field/focus/error outlines even though pure neumorphism examples often omit them.
7. Add painter/token/state tests, regression tests for helper/error placement and the existing low-memory responsive suite.
8. Compare on the phone at normal text first, then 200% text; tune centralized values once before completing TalkBack.

### Plain Pseudocode

```text
FOR each tactile surface:
    choose one shared elevation level based on its role
    paint a subtle light-to-dark surface gradient
    IF resting:
        paint a bright top-left shadow and tighter dark bottom-right shadow
    IF pressed:
        clip painting to the rounded shape
        paint the dark and light shadows inward
    IF focused or invalid:
        keep an explicit accessible outline above the decorative lighting

FOR each form field:
    paint depth around only the editable control body
    render helper or error text beneath that body
    keep the native TextField, label, focus, error and TalkBack behavior
```

### Second-Pass Acceptance Criteria

- [x] Resting and pressed controls reproduce the paired outer/inset lighting model in normal-scale ADB captures without a third-party UI dependency.
- [x] Primary actions have a subtle raised gradient/highlight while retaining compliant white-text contrast.
- [x] Registration helper and validation text sit outside the raised field body without clipping, shelves or semantic loss in automated layout/semantics checks.
- [x] Cards, fields, icon tiles and actions use distinct centralized depth levels.
- [x] Sign out and repeated secondary actions use the shared tactile language.
- [x] No behavior, route, API, database, dependency or permission boundary changes.
- [x] Analysis, 12 calibration-focused core UI tests and the complete 118-test low-memory suite pass.
- [ ] Chris accepts normal and 200% physical visuals before Home/account TalkBack closes the slice.

### Approval Gate

Chris explicitly approved this second amendment on 2026-09-07. It remains frontend presentation/test/documentation work only and does not authorize backend, database, dependency, customer-data or Git changes.

### Second-Pass Implementation Result

`KkDepth` now defines tile, control and panel elevations with one top-left light direction, and `KkGradients` supplies reusable panel, control, primary and disabled surfaces. `KkInnerShadow` uses a clipped `CustomPainter` to render paired inward shadows; native Material buttons remain responsible for callbacks, focus, semantics and disabled behavior. `KkFieldSurface` renders support/error text below the raised editable body and applies an explicit error border without putting text inside the shadow. Home Sign out now uses the same secondary tactile component.

The first authorized phone capture exposed a device-renderer issue: placing three outer shadows and the opaque panel gradient in one `BoxDecoration` washed major faces blue-gray. `KkSoftSurface` now paints those as two physical layers—a shadow-only backing and a separate opaque gradient face. Central tokens also use a paler face, lower shadow opacity, a less muddy orange grade and softer warm/blue inset shadows. A dedicated widget test locks the layer separation.

`dart format`, `flutter analyze`, 12 calibration-focused core UI tests and the complete 118-test low-memory suite passed. The private-HTTPS APK built and installed over the existing app without clearing its data. ADB captures verified normal-scale Home and Diagnostics in resting state plus primary and secondary pressed states; Chris acceptance, 200% visuals and Home/account TalkBack remain open.

## 13. Approved Exaggerated Depth and Blue Inset-Accent Amendment

### Request and Reference Finding

Chris's physical review found the calibrated depth clean but still too subtle for immediate human recognition. He first requested accent treatment for `Create a customer account` and `Resend verification email`, with a concave/inset appearance rather than another raised level. During implementation, his pure-neumorphism reference clarified that the functional accent must be blue rather than orange. The revised direction therefore keeps pale sculpted surfaces and uses blue consistently for selection, emphasis and primary actions.

The referenced [Neumorphism.io source repository](https://github.com/adamgiebl/neumorphism) confirms the underlying model: derive lighter and darker tones from one base color, keep one consistent light direction, scale blur with shadow distance, and apply the same paired shadows as `inset` for a concave shape. KK10P will translate this model into centralized Flutter tokens and the existing native painter; it will not copy source, add the React project or introduce a package.

### Scope

- Increase the existing tile/control/panel depth one controlled step using shared `KkDepth` values only.
- Preserve the shadow-backing/opaque-face separation that prevents the target Android renderer from tinting major panels.
- Add one reusable always-concave blue-accent action treatment for the two Login support actions.
- Replace the former orange action family centrally with an accessible blue family; do not recolor screens individually.
- Remove normal and pressed button outlines so controls read as sculpted from the canvas; retain a focus-only ring for non-touch navigation.
- Strengthen the shared top-left white halo slightly so depth remains obvious on the physical pale display without adding full-screen glow or blur.
- Retain native Flutter button semantics, keyboard focus, disabled behavior, 48-pixel targets and 200% scrolling.
- Do not change routes, registration, resend delivery, dialogs, authentication state, API calls, backend, database, dependencies or permissions.

### Plain Pseudocode

```text
FOR each shared raised depth role (tile, control, panel):
    preserve the top-left light and bottom-right dark direction
    increase contact-shadow distance and strength by one mobile-safe step
    add a small shared spread to the white highlight so the light edge is visible
    increase blur proportionally so the shadow remains soft
    keep panel shadow on its separate backing layer
    do not add per-screen shadow overrides

CREATE one shared inset-accent action:
    keep a native Flutter button as the interactive/semantic child
    paint a pale surface matching the KK10P canvas family
    show paired inner shadows while resting so the action reads concave
    use the blue action token for icon, label and a visible boundary
    IF pressed:
        deepen the inner shadow without translating or raising the control
    IF focused:
        strengthen the explicit blue outline
    IF disabled:
        mute the accent while keeping the label readable

ON Login:
    replace only the visual wrappers for Create customer and Resend verification
    preserve their existing callbacks, route and dialog

FOR every shared button variant:
    show no outline while resting or pressed
    IF keyboard-focused:
        show the explicit focus ring

VERIFY:
    assert the stronger shared depth remains centralized
    assert inset-accent semantics, minimum size, rest/press/focus/disabled states
    repeat Login at 320/360/412/768 widths and 200% text
    run analysis, focused UI tests and the full low-memory suite
    build/install with the runtime-only private HTTPS endpoint
    compare resting and pressed states on the authorized phone
```

### Acceptance Criteria

- [x] Raised cards, fields, tiles and ordinary actions read clearly as elevated at normal phone viewing distance without reintroducing blue-gray face wash.
- [x] The two Login support actions are reusable blue-accent inset controls, not one-off decorations or raised buttons.
- [x] Resting, pressed, focused and disabled inset-accent states remain distinct through text/icon/tone/depth cues and a focus-only ring.
- [x] Buttons use borderless sculpted rest/press states plus a focus-only ring; form-field and error boundaries remain explicit.
- [x] Login remains scrollable and actionable at supported widths and 200% text in automated responsive checks.
- [x] Existing Login registration navigation and resend-dialog behavior remain unchanged.
- [x] No backend, database, dependency, route, authentication-contract or permission change occurs.
- [x] Automated checks, a private-HTTPS APK build and normal-scale resting/pressed physical Android comparison pass.
- [x] Repeat the physical comparison at 200% text after ADB reconnects and restore the original device font scale.
- [ ] Obtain Chris's visual acceptance.

### Approval Gate

Chris approved Section 13 on 2026-09-07 and immediately refined its accent direction to blue using the supplied pure-neumorphism reference. That revision is treated as the authoritative implementation direction.

## 14. Proposed Bank-Restrained Material and Rapid-Interaction Calibration

### Evidence Reviewed

Chris supplied screenshots and authorized read-only inspection of the separate `Neumorphism-Music-Player-Android` prototype. It is a native Jetpack Compose app, not reusable Flutter code. Its transferable design recipe is:

- one cool-gray material family for both canvas and raised faces (`#E0E5EC` in the reference);
- a white upper-left light paired with a neutral blue-gray lower-right shadow (`#A3B1C6`);
- a vivid blue accent family (`#3B82F6`, with darker `#2563EB` and lighter `#60A5FA` roles);
- approximately 6 dp raised depth and 4 dp inset depth;
- immediate raised-to-sunken feedback from pointer down until release.

The music-player layout, vinyl artwork, rotary controls, numerous circular buttons and entertainment-style density are not suitable for KK10P and will not be copied. Its raw pointer handler also invokes the action after `tryAwaitRelease()` without checking whether the gesture was cancelled; KK10P will retain native Flutter buttons so cancelled gestures, keyboard operation, focus and semantics remain correct.

### Current KK10P Gaps

- The secondary control face grades from pure white to near-white, so it appears brighter and glossier than the reference's single sculpted material.
- The lower-right shadow is derived from navy, which can look muddier than the reference's neutral blue-gray shadow on the physical display.
- The shared outer container and inner-shadow transitions both use 120 ms; they pass state tests but the tests wait 150 ms and do not prove that feedback feels immediate during quick repeated taps.
- Existing login, registration and account controllers already reject duplicate in-flight operations, but this protection is not yet documented and tested as part of the tactile-control contract.

### Scope and Planned Files

| Path | Planned change |
| --- | --- |
| `mobile/banking_mobile/lib/core/theme/kk_theme.dart` | Add bank-adapted material, neutral shadow and accessible blue accent tokens derived from the reference; remove pure-white secondary faces without per-screen colors. |
| `mobile/banking_mobile/lib/core/ui/kk_embossed_controls.dart` | Calibrate shared raised/pressed transitions for immediate feedback while preserving native Material button behavior. |
| `mobile/banking_mobile/lib/core/ui/kk_inner_shadow.dart` | Align the inner transition duration with the shared button only if needed; keep the existing clipped painter. |
| `mobile/banking_mobile/test/core/ui/kk_embossed_controls_test.dart` | Assert pointer-down feedback, release restoration, cancelled-gesture safety, rapid valid taps and all accessibility states. |
| Existing authentication/account controller tests | Assert sensitive async actions remain single-flight under rapid repeated invocation; do not add a global debounce. |
| Canonical design, walkthrough, task, README and changelog | Record the approved token values, interaction contract and verified device result. |

### Plain Pseudocode

```text
READ the reference values as design evidence only
DO NOT copy Kotlin source, layouts, artwork or dependencies

DEFINE one bank-adapted material family:
    keep the canvas and ordinary raised control faces tonally close
    use white only as the upper-left light, not as the whole control face
    use neutral blue-gray for the lower-right shadow
    use vivid blue for icons, selection and accents on pale surfaces
    use the darker blue for filled actions when white text needs stronger contrast

FOR each shared native button:
    WHEN pointer goes down on an enabled button:
        show the sunken state immediately within one rendered frame
    WHEN a valid pointer is released:
        restore the raised state quickly
        invoke the callback exactly once
    WHEN the gesture is cancelled or leaves the target:
        restore the raised state
        do not invoke the callback
    WHEN disabled or submitting:
        do not invoke the callback
        retain a visibly disabled state

FOR authentication and account mutations:
    preserve the existing controller single-flight guard
    do not use an arbitrary time-based debounce
    verify rapid repeated calls produce at most one in-flight repository request

VERIFY normal, pressed, cancelled, focused and disabled behavior
VERIFY 48-pixel targets, native semantics, contrast and 200% scrolling
RUN formatting, analysis, focused tests and the full low-memory suite
BUILD and install using the runtime-only private HTTPS API value
COMPARE the result on the authorized phone at normal and 200% text
```

### Acceptance Criteria

- [x] Ordinary raised controls look sculpted from the page material rather than placed on top as bright white cards.
- [x] Upper-left light and lower-right shadow remain clearly visible without the heavy entertainment-style depth of the music player.
- [x] Blue accent roles are centralized; filled buttons use a contrast-safe darker blue while pale-surface icons may use the brighter reference blue.
- [x] An enabled button shows pressed depth on pointer down within one frame and settles promptly on release without a forced minimum hold.
- [x] A valid tap invokes one callback; a cancelled gesture invokes none; rapid valid taps remain responsive for non-sensitive local actions.
- [x] Login, registration and account-opening operations remain single-flight while busy, with no global debounce that makes the app feel unresponsive.
- [x] Native focus, keyboard, TalkBack, disabled state and minimum 48-pixel target behavior remain intact in automated checks; the agreed human Home/account TalkBack check remains open.
- [x] Existing routes, API contracts, authentication, account state, database and dependencies remain unchanged.
- [x] Responsive checks pass at 320/360/412/768 widths and 200% text, followed by agent physical normal/pressed/rapid-tap review on the authorized phone.
- [x] `flutter analyze`, focused tests, the complete low-memory Flutter suite and the private-HTTPS APK build pass before Chris's visual acceptance.

### Approval Gate

Chris explicitly approved Section 14 on 2026-09-07. Approval authorized Flutter presentation/state tests and aligned documentation only; it did not authorize backend, API, database, migration, dependency, external-reference, customer-data or Git changes.

### Implementation Result

KK10P keeps its pale-blue `#EAF1F8` canvas rather than copying the music player's gray page. Ordinary controls now use that same material tone, while major panels retain a restrained `#F3F7FB` to `#E6EEF6` hierarchy. The reference's neutral `#A3B1C6` shadow family replaces navy-derived dark shadows. Pale-surface accents use `#3B82F6`; filled actions use the darker `#2563EB` to `#1D4ED8` gradient so white text passes the automated 4.5:1 contrast gate.

`KkMotion.press` centralizes a 70 ms transition used by both the shared button shell and inner-shadow painter. Native Flutter buttons still own down, release, cancellation, focus and semantics. No global debounce was added. Login, registration and account opening retain their existing state/controller single-flight guards, with new deterministic tests for login and registration joining the existing account duplicate-opening test.

Formatting completed, `flutter analyze` passed, Section 14 focused checks passed 33/33, and the complete single-worker Flutter suite passed 126/126. The private-HTTPS debug APK built and installed over the existing app without clearing data. Local and private diagnostics returned HTTP 200. ADB review covered Login rest/primary press, Home secondary rest/press, three rapid Refresh taps and 200% top/scrolled states with no crash lines; the original 1.0 font scale was restored. Chris visual acceptance and the human Home/account TalkBack review remain open.

## 15. Proposed Final Pure-Neumorphism Alignment

### Request and Evidence

Chris's split-screen comparison on 2026-09-07 failed the Section 14 visual-acceptance gate and clarified that the complete current KK10P frontend should use the music-player prototype's pure-neumorphism material language, not the earlier bank-restrained hybrid. Business behavior, screen content and navigation stay unchanged.

Read-only inspection of the reference source confirms that its appearance comes from one solid material plus directional shadows, not 3D models or artwork:

- canvas and surface: `#E0E5EC`;
- primary, secondary and tertiary text: `#2D3748`, `#718096` and `#A0AEC0`;
- blue accent family: `#3B82F6`, `#2563EB` and `#60A5FA`;
- upper-left light: white at approximately 85% opacity;
- lower-right shadow: `#A3B1C6` at approximately 65% opacity;
- raised geometry: one light shadow and one dark shadow at about 6 dp elevation, 16 dp control radius and 20 dp card radius;
- inset geometry: `#D9DFE8` base with dark upper-left and light lower-right inner shading at about 4 dp depth.

### Exact Cause of the Remaining Mismatch

- KK10P still uses a bluer `#EAF1F8` canvas instead of the reference `#E0E5EC` material.
- Raised panels still use a lighter `#F3F7FB` to `#E6EEF6` gradient, so they read as separate white cards.
- `KkSoftSurface`, `KkFieldSurface` and `KkIconTile` still paint full-perimeter white borders. The apparent wide rim is not merely excessive border width; it is the combination of that border, a lighter face and shadows.
- Panel/control depth uses two lower-right dark shadows plus spread, whereas the reference uses one simple light/dark pair with no border or extra shadow layer.
- The AppBar keeps a bottom divider, ordinary fields are raised rather than reference-style inset, and primary actions use a blue gradient instead of a solid reference accent.
- KK10P still uses navy text roles rather than the reference's softer gray text hierarchy.

### Scope and Planned Files

| Path | Planned change |
| --- | --- |
| `mobile/banking_mobile/lib/core/theme/kk_theme.dart` | Replace the hybrid palette, gradients, radii, dividers and triple-shadow depth with the exact reference material/text/accent tokens and one raised light/dark pair. Preserve semantic error/success contrast. |
| `mobile/banking_mobile/lib/core/ui/kk_soft_surface.dart` | Make raised, inset and flat surfaces use the same solid material; remove resting perimeter borders and the shadow-only backing workaround. |
| `mobile/banking_mobile/lib/core/ui/kk_embossed_controls.dart` | Make ordinary buttons and icon tiles borderless raised material, make fields/support actions truly inset, use a solid blue primary action, and preserve focus/error outlines only when semantically required. |
| `mobile/banking_mobile/lib/core/ui/kk_inner_shadow.dart` | Calibrate the painter to the reference's dark-upper-left/light-lower-right inset recipe without changing hit testing. |
| Existing Startup, Login, Registration, Verification, Diagnostics and Home/account presentation files | Remove direct hybrid-only decoration, apply the shared pure-neumorphic status/action/icon patterns, and keep all labels, routes, states and business operations unchanged. |
| Existing theme, shared-control, responsive and screen tests | Replace hybrid-token expectations; assert borderless resting surfaces, two-shadow raised geometry, inset field geometry, focus/error exceptions, 70 ms native interaction and unchanged screen behavior. |
| Design source, walkthrough, active task, README and changelog | Record the approved pure-neumorphism contract and truthful verification result after implementation. |

### Plain Pseudocode

```text
READ the local music-player source as visual evidence only
DO NOT copy its Kotlin layout, music features, artwork, pointer handler or dependencies

DEFINE one shared material:
    canvas = surface = raised face = #E0E5EC
    text roles = #2D3748 / #718096 / #A0AEC0
    accent roles = #3B82F6 / #2563EB / #60A5FA

FOR every resting raised surface:
    draw one solid #E0E5EC face
    draw one soft white upper-left shadow
    draw one soft #A3B1C6 lower-right shadow
    draw no perimeter border, gradient, spread halo or extra dark shadow

FOR every input and intentionally sunken action:
    draw the #D9DFE8 inset base
    draw dark shading from the upper-left inside edge
    draw light shading toward the lower-right inside edge
    keep a visible outline only for keyboard focus or validation error

FOR blue primary actions and selected states:
    use a solid accent role, not a glossy gradient
    preserve white-text contrast and disabled differentiation

KEEP native Flutter button semantics and the shared 70 ms press response
KEEP cancelled-gesture behavior and controller single-flight guards
KEEP every existing route, label, API call, loading/error/empty state and permission boundary

VERIFY every current frontend screen at 320/360/412/768 widths and 200% text
VERIFY rest, focus, press, cancel, disabled, loading, error and success states
BUILD and install with the runtime-only private HTTPS endpoint
COMPARE Login, Registration, Diagnostics and Home against the reference on the same phone
ADJUST only shared renderer translation values if Flutter and Compose blur differently
RESTORE the phone's original accessibility settings
```

### Acceptance Criteria

- [ ] Every current customer-facing screen uses `#E0E5EC` for the page and ordinary surface material; no hybrid `#EAF1F8` or light panel gradient remains.
- [ ] Resting cards, fields, icon tiles and buttons have no decorative full-perimeter border. Keyboard-focus and validation-error outlines remain allowed and visually distinct.
- [ ] Each raised surface uses exactly one upper-left light and one lower-right dark shadow, with no third shadow or spread halo.
- [ ] Cards use the shared 20 dp radius and ordinary controls use the shared 16 dp radius unless a circular icon control is intentional.
- [ ] Inputs and designated inset actions visibly use the reference-style dark-upper-left/light-lower-right basin.
- [ ] Primary actions and selected states use the blue accent family without orange or glossy gradients, while text meets the automated contrast threshold.
- [ ] The AppBar, dialogs, loading, error, success, disabled and empty states visually belong to the same material family.
- [ ] Existing content, routes, authentication, account behavior, API contracts, controller guards and database behavior are unchanged.
- [ ] Native semantics, keyboard focus, TalkBack labels, cancelled gestures, 48-pixel targets, 70 ms feedback and 200% text reachability remain intact.
- [ ] Formatting, `flutter analyze`, focused UI tests, the complete low-memory suite, APK build and physical same-phone comparisons pass.
- [ ] Chris accepts the physical result before this visual foundation is archived.

### Optional Gemini Visual-Review Prompt

```text
Act as a mobile UI visual-difference reviewer. The attached split-screen image shows a Jetpack Compose neumorphic music app on top and the current Flutter KK10P Bank frontend on the bottom. Analyze appearance only. Do not redesign banking flows, suggest backend/database/API changes, add screens, or generate unrelated features.

The top app's source tokens are known: background/surface #E0E5EC, text #2D3748/#718096/#A0AEC0, accent #3B82F6 with #2563EB and #60A5FA roles, white upper-left shadow around 85% opacity, #A3B1C6 lower-right shadow around 65% opacity, about 6 dp raised depth, 4 dp inset depth, 16 dp control radius and 20 dp card radius. Raised surfaces use one light plus one dark shadow and no border. Inset surfaces use a #D9DFE8 base with dark upper-left and light lower-right inner shading.

Compare only the existing frontend elements visible in KK10P: page/AppBar, account card, icon tile, balance text, secondary button and spacing. Explain precisely why KK10P still looks hybrid instead of pure neumorphism. Separate differences caused by surface color, gradients, borders, number/direction/blur of shadows, radius, typography color and raised-versus-inset state. Do not infer exact physical dimensions from split-screen scaling.

Return:
1. A prioritized visual-delta list.
2. A compact Flutter token recipe using Color, BoxShadow and radius values—not a full application rewrite.
3. Which elements should be raised, inset, flat or solid-blue.
4. A pass/fail checklist for Login, Registration, Email Verification, Diagnostics and Home/account screens.
5. Any accessibility warning where pure neumorphism needs a focus/error exception.
```

### Approval Gate

Section 15 was planned but not approved or implemented. It is superseded by the broader, prototype-informed [KK10P prototype-to-Flutter master roadmap](plan-kk10p-prototype-to-flutter-roadmap.md), which preserves the pure same-material lighting principle while replacing this narrow token-only pass with an approved screen and feature adoption sequence.
