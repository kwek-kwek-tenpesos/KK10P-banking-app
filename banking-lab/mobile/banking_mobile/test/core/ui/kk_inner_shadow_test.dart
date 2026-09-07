import 'package:banking_mobile/core/ui/kk_inner_shadow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('inner shadow keeps its child and exposes the painter', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 72,
              child: KkInnerShadow(
                visible: true,
                child: ColoredBox(color: Color(0xFFF4F8FC)),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ColoredBox), findsWidgets);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    final innerShadowPaints = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(KkInnerShadow),
            matching: find.byType(CustomPaint),
          ),
        )
        .where((paint) => paint.foregroundPainter is KkInnerShadowPainter);
    expect(innerShadowPaints, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  test('inner shadow painter repaints only when lighting changes', () {
    const original = KkInnerShadowPainter(
      borderRadius: 12,
      darkColor: Color(0x66315B7D),
      lightColor: Color(0xE6FFFFFF),
      offset: Offset(4, 4),
      blurSigma: 5,
    );
    const same = KkInnerShadowPainter(
      borderRadius: 12,
      darkColor: Color(0x66315B7D),
      lightColor: Color(0xE6FFFFFF),
      offset: Offset(4, 4),
      blurSigma: 5,
    );
    const changed = KkInnerShadowPainter(
      borderRadius: 12,
      darkColor: Color(0x66315B7D),
      lightColor: Color(0xE6FFFFFF),
      offset: Offset(4, 4),
      blurSigma: 7,
    );

    expect(original.shouldRepaint(same), isFalse);
    expect(original.shouldRepaint(changed), isTrue);
  });
}
