import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_embossed_controls.dart';
import 'package:banking_mobile/core/ui/kk_inner_shadow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget testApp(Widget child) {
    return MaterialApp(
      theme: KkTheme.light(),
      home: Scaffold(
        body: Center(child: SizedBox(width: 260, child: child)),
      ),
    );
  }

  testWidgets('embossed primary button keeps native button semantics', (
    tester,
  ) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      testApp(
        KkEmbossedButton(
          variant: KkEmbossedButtonVariant.primary,
          onPressed: () => taps++,
          icon: const Icon(Icons.login),
          label: const Text('Sign in'),
        ),
      ),
    );

    final button = find.widgetWithText(FilledButton, 'Sign in');
    expect(button, findsOneWidget);
    final decoration =
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byType(KkEmbossedButton),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(decoration.gradient, KkGradients.primaryAction);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(button),
      matchesSemantics(
        label: 'Sign in',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(button);
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets(
    'embossed button swaps outer depth for inner depth when pressed',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          KkEmbossedButton(
            onPressed: () {},
            label: const Text('Refresh balance'),
          ),
        ),
      );

      final animated = find.descendant(
        of: find.byType(KkEmbossedButton),
        matching: find.byType(AnimatedContainer),
      );
      final restingDecoration =
          tester.widget<AnimatedContainer>(animated).decoration!
              as BoxDecoration;
      expect(
        tester.widget<AnimatedContainer>(animated).duration,
        KkMotion.press,
      );
      expect(restingDecoration.boxShadow, hasLength(2));
      expect(restingDecoration.gradient, KkGradients.control);
      expect(
        tester.widget<KkInnerShadow>(find.byType(KkInnerShadow)).visible,
        isFalse,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Refresh balance')),
      );
      await tester.pump();

      final pressedDecoration =
          tester.widget<AnimatedContainer>(animated).decoration!
              as BoxDecoration;
      expect(pressedDecoration.boxShadow, isEmpty);
      expect(
        tester.widget<KkInnerShadow>(find.byType(KkInnerShadow)).visible,
        isTrue,
      );

      await gesture.up();
      await tester.pump(KkMotion.press);
      final releasedDecoration =
          tester.widget<AnimatedContainer>(animated).decoration!
              as BoxDecoration;
      expect(releasedDecoration.boxShadow, KkDepth.control);
      expect(
        tester.widget<KkInnerShadow>(find.byType(KkInnerShadow)).visible,
        isFalse,
      );
    },
  );

  testWidgets('cancelled press restores depth without invoking the callback', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        KkEmbossedButton(
          onPressed: () => taps++,
          label: const Text('Safe action'),
        ),
      ),
    );

    final animated = find.descendant(
      of: find.byType(KkEmbossedButton),
      matching: find.byType(AnimatedContainer),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Safe action')),
    );
    await tester.pump();
    expect(
      tester.widget<KkInnerShadow>(find.byType(KkInnerShadow)).visible,
      isTrue,
    );

    await gesture.cancel();
    await tester.pump(KkMotion.press);

    expect(taps, 0);
    expect(
      (tester.widget<AnimatedContainer>(animated).decoration! as BoxDecoration)
          .boxShadow,
      KkDepth.control,
    );
    expect(
      tester.widget<KkInnerShadow>(find.byType(KkInnerShadow)).visible,
      isFalse,
    );
  });

  testWidgets('rapid valid taps stay responsive without a global debounce', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        KkEmbossedButton(
          onPressed: () => taps++,
          label: const Text('Local action'),
        ),
      ),
    );

    final action = find.text('Local action');
    await tester.tap(action);
    await tester.tap(action);
    await tester.tap(action);
    await tester.pump(KkMotion.press);

    expect(taps, 3);
  });

  testWidgets('disabled embossed button removes misleading raised shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const KkEmbossedButton(onPressed: null, label: Text('Unavailable')),
      ),
    );

    final animated = find.descendant(
      of: find.byType(KkEmbossedButton),
      matching: find.byType(AnimatedContainer),
    );
    final decoration =
        tester.widget<AnimatedContainer>(animated).decoration! as BoxDecoration;
    expect(decoration.boxShadow, isEmpty);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('keyboard focus adds an explicit border', (tester) async {
    await tester.pumpWidget(
      testApp(
        KkEmbossedButton(
          onPressed: () {},
          label: const Text('API diagnostics'),
        ),
      ),
    );

    final animated = find.descendant(
      of: find.byType(KkEmbossedButton),
      matching: find.byType(AnimatedContainer),
    );
    final restingDecoration =
        tester.widget<AnimatedContainer>(animated).decoration! as BoxDecoration;
    expect(restingDecoration.border, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final focusedDecoration =
        tester.widget<AnimatedContainer>(animated).decoration! as BoxDecoration;
    expect(focusedDecoration.border!.top.width, 2);
    expect(focusedDecoration.border!.top.color, KkColors.primary);
  });

  testWidgets('inset accent action stays concave and deepens when pressed', (
    tester,
  ) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        KkEmbossedButton(
          variant: KkEmbossedButtonVariant.insetAccent,
          onPressed: () => taps++,
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Create a customer account'),
        ),
      ),
    );

    final action = find.widgetWithText(TextButton, 'Create a customer account');
    final animated = find.descendant(
      of: find.byType(KkEmbossedButton),
      matching: find.byType(AnimatedContainer),
    );
    final restingDecoration =
        tester.widget<AnimatedContainer>(animated).decoration! as BoxDecoration;
    final restingInnerShadow = tester.widget<KkInnerShadow>(
      find.byType(KkInnerShadow),
    );

    expect(restingDecoration.gradient, KkGradients.insetControl);
    expect(restingDecoration.boxShadow, isEmpty);
    expect(restingDecoration.border, isNull);
    expect(restingInnerShadow.visible, isTrue);
    expect(restingInnerShadow.offset, const Offset(4, 4));
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(action),
      matchesSemantics(
        label: 'Create a customer account',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(action));
    await tester.pump();
    final pressedDecoration =
        tester.widget<AnimatedContainer>(animated).decoration! as BoxDecoration;
    final pressedInnerShadow = tester.widget<KkInnerShadow>(
      find.byType(KkInnerShadow),
    );
    expect(pressedDecoration.gradient, KkGradients.insetPressed);
    expect(pressedInnerShadow.visible, isTrue);
    expect(pressedInnerShadow.offset, const Offset(5, 5));
    expect(pressedInnerShadow.blurSigma, 8);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('disabled inset accent action is visibly muted', (tester) async {
    await tester.pumpWidget(
      testApp(
        const KkEmbossedButton(
          variant: KkEmbossedButtonVariant.insetAccent,
          onPressed: null,
          label: Text('Resend verification email'),
        ),
      ),
    );

    final animated = find.descendant(
      of: find.byType(KkEmbossedButton),
      matching: find.byType(AnimatedContainer),
    );
    final decoration =
        tester.widget<AnimatedContainer>(animated).decoration! as BoxDecoration;
    final button = tester.widget<TextButton>(find.byType(TextButton));

    expect(decoration.gradient, KkGradients.disabledControl);
    expect(decoration.boxShadow, isEmpty);
    expect(decoration.border, isNull);
    expect(
      tester.widget<KkInnerShadow>(find.byType(KkInnerShadow)).visible,
      isFalse,
    );
    expect(
      button.style!.foregroundColor!.resolve({WidgetState.disabled}),
      KkMaterialTokens.light.textSecondary.withAlpha(150),
    );
  });

  testWidgets('field and icon tiles use shared gradient depth', (tester) async {
    await tester.pumpWidget(
      testApp(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KkFieldSurface(
              child: TextField(
                decoration: InputDecoration(labelText: 'Email address'),
              ),
            ),
            SizedBox(height: 24),
            KkIconTile(icon: Icons.account_balance_wallet_outlined),
          ],
        ),
      ),
    );

    final decorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>();
    expect(
      decorations.where(
        (decoration) =>
            decoration.boxShadow?.length == 2 &&
            decoration.gradient == KkMaterialTokens.light.raisedGradient,
      ),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('field support text sits below the raised control body', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const KkFieldSurface(
          helperText: 'Max 60 characters',
          child: TextField(
            decoration: InputDecoration(labelText: 'Display name'),
          ),
        ),
      ),
    );

    final field = find.byType(TextField);
    final helper = find.text('Max 60 characters');
    expect(helper, findsOneWidget);
    expect(
      tester.getBottomLeft(field).dy,
      lessThan(tester.getTopLeft(helper).dy),
    );

    final decoratedControl = find.ancestor(
      of: field,
      matching: find.byType(DecoratedBox),
    );
    expect(decoratedControl, findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('field error text is external and announced as a live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        const KkFieldSurface(
          errorText: 'Enter a valid email address.',
          child: TextField(
            decoration: InputDecoration(labelText: 'Email address'),
          ),
        ),
      ),
    );

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    final surface = find.byType(KkFieldSurface);
    expect(tester.getSemantics(surface).flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });
}
