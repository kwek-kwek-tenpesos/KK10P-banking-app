import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_page_body.dart';
import 'package:banking_mobile/core/ui/kk_soft_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light material and accent tokens keep bank-safe contrast', () {
    expect(KkColors.surface, KkColors.background);
    expect(KkColors.background, const Color(0xFFECEDE9));
    expect(KkColors.darkShadow, const Color(0xFF9EA3A1));
    expect(KkColors.accent, const Color(0xFF2563EB));
    expect(KkColors.action, const Color(0xFF2563EB));
    expect(KkGradients.control.colors, const [
      Color(0xFFF7F7F3),
      Color(0xFFE5E6E2),
    ]);

    final whiteTextContrast =
        (Colors.white.computeLuminance() + 0.05) /
        (KkColors.action.computeLuminance() + 0.05);
    expect(whiteTextContrast, greaterThanOrEqualTo(4.5));
    expect(KkMotion.press, lessThanOrEqualTo(const Duration(milliseconds: 80)));
  });

  test('dark material is independently tuned and keeps action contrast', () {
    const tokens = KkMaterialTokens.dark;
    expect(tokens.canvas, const Color(0xFF22262B));
    expect(tokens.surfaceStart, isNot(tokens.canvas));
    expect(tokens.primary, const Color(0xFF60A5FA));
    expect(tokens.lightShadow.a, lessThan(0.5));
    expect(tokens.primaryDepth.first.color, tokens.primaryLightShadow);
    expect(tokens.primaryDepth.last.color, tokens.primaryDarkShadow);
    expect(tokens.surfaceBorder.a, greaterThan(0));
    expect(tokens.panelDepth.last.blurRadius, 12);

    final actionContrast =
        (tokens.primary.computeLuminance() + 0.05) /
        (tokens.onPrimary.computeLuminance() + 0.05);
    expect(actionContrast, greaterThanOrEqualTo(4.5));
  });

  test('depth roles share one light direction but remain distinct', () {
    for (final depth in [KkDepth.tile, KkDepth.control, KkDepth.panel]) {
      expect(depth, hasLength(2));
      expect(depth.first.offset.dx, lessThan(0));
      expect(depth.first.offset.dy, lessThan(0));
      expect(depth[1].offset.dx, greaterThan(0));
      expect(depth[1].offset.dy, greaterThan(0));
    }

    expect({
      KkDepth.tile[1].blurRadius,
      KkDepth.control[1].blurRadius,
      KkDepth.panel[1].blurRadius,
    }, hasLength(3));
    expect(
      KkDepth.control[1].blurRadius,
      lessThan(KkDepth.panel[1].blurRadius),
    );
    expect(KkDepth.primary.first.offset, const Offset(-1, -1));
    expect(KkDepth.primary[1].offset, const Offset(2, 2));
    expect(KkDepth.primary[1].blurRadius, 5);
  });

  test('light and dark themes expose their matching material extension', () {
    expect(
      KkTheme.light().extension<KkMaterialTokens>(),
      KkMaterialTokens.light,
    );
    expect(KkTheme.dark().extension<KkMaterialTokens>(), KkMaterialTokens.dark);
  });

  testWidgets('raised surface isolates its shadow from its opaque face', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KkTheme.light(),
        home: const Scaffold(
          body: KkSoftSurface(child: Text('Layered surface')),
        ),
      ),
    );

    final decorations = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(KkSoftSurface),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .toList();

    expect(
      decorations,
      contains(
        isA<BoxDecoration>()
            .having((value) => value.gradient, 'gradient', isNull)
            .having((value) => value.boxShadow, 'shadow', KkDepth.panel),
      ),
    );
    expect(
      decorations,
      contains(
        isA<BoxDecoration>()
            .having((value) => value.gradient, 'gradient', KkGradients.panel)
            .having((value) => value.boxShadow, 'shadow', isNull)
            .having(
              (value) => value.border?.top,
              'hairline border',
              BorderSide(
                color: KkMaterialTokens.light.surfaceBorder,
                width: 0.75,
              ),
            ),
      ),
    );
  });

  testWidgets('KK10P foundation stays usable at 320 width and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: KkTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: KkPageBody(
              child: KkSoftSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TextField(
                      decoration: InputDecoration(labelText: 'Example field'),
                    ),
                    const SizedBox(height: KkSpacing.md),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Example action'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(KkSoftSurface), findsOneWidget);
    expect(
      tester
          .getSize(find.widgetWithText(FilledButton, 'Example action'))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      isNull,
    );
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      KkColors.background,
    );
  });
}
