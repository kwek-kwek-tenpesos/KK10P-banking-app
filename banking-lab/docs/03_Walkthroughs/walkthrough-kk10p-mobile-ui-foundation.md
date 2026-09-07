# Walkthrough: KK10P Mobile UI Foundation

## Outcome

The existing functional customer journey now shares one accessible blue-accent neumorphic foundation with canvas-matched controls, neutral paired shadows, graded primary actions and true inset states. Startup, login, registration, email verification, diagnostics, Home and account states were restyled without changing routes, controller commands, API calls, database behavior or feature availability.

The implementation deliberately exposes no transfer, history, profile, KYC or administrator control. Those features require their own behavior and security plans.

## Logic Flow

1. `BankingLabApp` applies `KkTheme.light()` once.
2. The existing router restores authentication and selects the same route as before.
3. Each screen uses `KkPageBody` for a safe, centered, width-limited and scrollable layout.
4. Content groups use `KkSoftSurface` in raised, inset or flat form. A raised surface paints its shadow backing separately from its opaque gradient face; this preserves the pale color on the target Android renderer. Repeated actions use `KkEmbossedButton`; authentication fields use `KkFieldSurface`; compact brand/account marks use `KkIconTile`.
5. Each shared tactile action still contains a native Flutter `FilledButton`, `OutlinedButton` or `TextButton`, so callbacks, keyboard focus, semantics and widget tests remain intact.
6. Pressing a raised action removes its outer shadows and reveals a clipped paired inner-shadow painter. `KkMotion.press` gives both layers the same 70 ms response. The two Login support actions use the same component's `insetAccent` variant: they remain concave at rest and deepen their inner shadow and pale basin when pressed. Buttons are borderless at rest/press; focus alone adds an explicit ring, and disabled controls lose misleading raised depth and mute their content. Form fields retain explicit editable/focus/error boundaries, so meaning is not carried by lighting alone.
7. Existing Riverpod controllers still own login, registration, verification, account loading/opening/refresh and logout behavior.
8. Loading, validation, error, success and retry states remain visible. Password visibility controls keep changing spoken labels.

## Three Concepts to Learn

### Design tokens

Design tokens are named values for repeated visual decisions, such as `KkColors.primary`, `KkSpacing.lg` and `KkRadius.medium`. Changing a token updates all consumers consistently and avoids hunting for unrelated hard-coded colors.

### Reusable composition

`KkPageBody` and `KkSoftSurface` are small widgets composed around ordinary Flutter controls. They reuse layout and appearance while leaving screen-specific behavior in the screen. This is modularity without creating a separate file for every line or action.

### Separation of presentation and behavior

The screen decides what the user sees; Riverpod controllers/repositories decide what happens. The redesign changed presentation imports and widget structure, but it did not rewrite authentication, session or account rules. That separation is why the existing end-to-end widget tests could remain authoritative.

### Interaction state

An interaction state describes whether a control is resting, pressed, focused or disabled. `KkEmbossedButton` listens to the native button's state controller and changes only its surrounding visual depth. It never replaces the real button or its callback, which keeps valid release, cancelled-gesture, keyboard and accessibility behavior separate from decoration. There is no global time-based debounce: controllers synchronously enter submitting/opening state to keep sensitive requests single-flight, while separate valid local taps remain responsive.

### Custom painting

Flutter's ordinary box shadows are outward shadows. `KkInnerShadowPainter` clips drawing to the rounded component, creates an even-odd path around a shifted inner hole, and blurs that path twice: dark from the top-left and light from the bottom-right. This creates the concave illusion without importing a UI package or changing the underlying button semantics. The Login support actions keep the painter visible at rest and strengthen it while pressed.

## Key Paths

- Theme tokens and Material component defaults: `mobile/banking_mobile/lib/core/theme/kk_theme.dart`
- Raised/inset/flat surface: `mobile/banking_mobile/lib/core/ui/kk_soft_surface.dart`
- Tactile buttons, field surfaces and icon tiles: `mobile/banking_mobile/lib/core/ui/kk_embossed_controls.dart`
- Native clipped inner-shadow painter: `mobile/banking_mobile/lib/core/ui/kk_inner_shadow.dart`
- Responsive scrollable page shell: `mobile/banking_mobile/lib/core/ui/kk_page_body.dart`
- App theme entry point: `mobile/banking_mobile/lib/app/app.dart`
- Startup styling: `mobile/banking_mobile/lib/app/app_router.dart`
- Customer auth screens: `mobile/banking_mobile/lib/features/authentication/presentation/screens/`
- Home shell: `mobile/banking_mobile/lib/features/home/presentation/screens/customer_home_screen.dart`
- Account states: `mobile/banking_mobile/lib/features/accounts/presentation/widgets/account_card.dart`
- Developer diagnostics: `mobile/banking_mobile/lib/features/system_info/presentation/screens/system_info_screen.dart`
- Foundation tests: `mobile/banking_mobile/test/core/ui/kk_theme_test.dart` and `mobile/banking_mobile/test/core/ui/kk_embossed_controls_test.dart`

## Safe Customization Points

- Adjust brand colors, spacing, corners and shared shadow strength in `kk_theme.dart` first. Change tactile control composition in `kk_embossed_controls.dart`, not independently in each screen.
- Replace the Material bank icon later where it appears in startup/login; do not embed a permanent asset until a logo is approved.
- Keep form labels, state messages and controller calls stable unless a separately approved behavior change requires them.
- Do not make shadows the only boundary. Keep input/error boundaries, text labels and focus-only rings visible; ordinary button rest/press states intentionally remain borderless.
- Add future screens only after their routes, states, API contracts and permissions exist; decorative disabled navigation is intentionally absent.

## Verification

- `dart format lib test` — completed on 2026-09-07.
- `flutter analyze` — passed with no issues.
- Second-pass painter/theme/responsive/regression tests — 39/39 passed.
- Calibration-focused core UI tests — 12/12 passed, including the raised backing/face layer regression.
- Section 13 focused theme/control/journey tests — 20/20 passed, including blue inset rest/press/disabled states, focus-only borders and preserved registration/resend behavior.
- Section 14 focused theme/control/controller tests — 33/33 passed, including next-frame press feedback, cancelled gesture, rapid valid taps and single-flight login/registration/account opening.
- `flutter test --concurrency=1` — 126/126 passed after the material and rapid-interaction calibration.
- `flutter build apk --debug` with the active runtime-only private HTTPS define — succeeded. No endpoint was saved or committed.
- Live diagnostics — the running API returned HTTP 200 through loopback and the existing private HTTPS route.
- The default parallel full-suite attempt exhausted Windows memory while launching test workers. It produced no assertion result and was replaced by the successful single-worker run.
- Physical Android review — the final private-HTTPS APK installed over the existing app with data preserved. ADB captures confirmed canvas-matched ordinary controls, neutral lower-right shadows, blue role separation, primary/secondary resting and pressed states, and stability after three rapid Refresh taps with no crash lines. Physical 200% top/scrolled captures remained usable; the original 1.0 font scale was restored. Chris acceptance remains pending.
- Home/account TalkBack listening — pending by explicit agreement; pre-redesign Login listening was reported working.

## Manual Phone Checklist

1. Reconnect the test phone and confirm it appears in `flutter devices`.
2. Install a debug build using the existing private HTTPS `API_BASE_URL`; never commit that address.
3. Check startup, Login, Create Account, verification/developer diagnostics and authenticated Home/account at normal text size.
4. Set font size to 200%, confirm content scrolls and Sign in/Open account/Refresh/Sign out remain reachable.
5. Enable TalkBack and listen in this order: app title, greeting/session status, Simulator funds, balance or unopened/error state, account reference if present, Refresh/Retry/Open account, Sign out, diagnostics.
6. Confirm the password toggle announces `Show password`, then `Hide password` after activation.
7. Report clipping, unclear surface boundaries, wrong spoken labels or confusing order. Tune centralized tokens/components rather than patching one screen unless the issue is unique.
