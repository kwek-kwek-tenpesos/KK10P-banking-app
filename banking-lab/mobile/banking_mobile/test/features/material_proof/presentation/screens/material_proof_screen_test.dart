import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/features/material_proof/presentation/screens/material_proof_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget testApp({MediaQueryData? mediaQueryData}) {
    final screen = const MaterialProofScreen();
    return MaterialApp(
      theme: KkTheme.light(),
      home: mediaQueryData == null
          ? screen
          : MediaQuery(data: mediaQueryData, child: screen),
    );
  }

  testWidgets('switches between independently tuned light and dark proofs', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());

    expect(find.text('Light proof'), findsOneWidget);
    var scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('material-proof-scaffold')),
    );
    var context = tester.element(find.text('Light proof'));
    expect(
      Theme.of(context).extension<KkMaterialTokens>(),
      KkMaterialTokens.light,
    );
    expect(scaffold.backgroundColor, isNull);
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      KkMaterialTokens.light.canvas,
    );

    await tester.tap(find.byTooltip('Switch to dark theme'));
    await tester.pumpAndSettle();

    expect(find.text('Dark proof'), findsOneWidget);
    scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('material-proof-scaffold')),
    );
    context = tester.element(find.text('Dark proof'));
    expect(
      Theme.of(context).extension<KkMaterialTokens>(),
      KkMaterialTokens.dark,
    );
    expect(scaffold.backgroundColor, isNull);
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      KkMaterialTokens.dark.canvas,
    );
  });

  testWidgets('proof remains scrollable at 320 width and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testApp(
        mediaQueryData: const MediaQueryData(
          size: Size(320, 900),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Primary action'), findsOneWidget);
  });
}
