import 'dart:ui' as ui;

import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:flutter/material.dart';

class KkInnerShadow extends StatelessWidget {
  const KkInnerShadow({
    required this.child,
    required this.visible,
    super.key,
    this.borderRadius = 12,
    this.darkColor = const Color(0xB3A3B1C6),
    this.lightColor = const Color(0xBFFFFFFF),
    this.offset = const Offset(3, 3),
    this.blurSigma = 6,
  });

  final Widget child;
  final bool visible;
  final double borderRadius;
  final Color darkColor;
  final Color lightColor;
  final Offset offset;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: KkMotion.press,
                curve: Curves.easeOutCubic,
                opacity: visible ? 1 : 0,
                child: CustomPaint(
                  foregroundPainter: KkInnerShadowPainter(
                    borderRadius: borderRadius,
                    darkColor: darkColor,
                    lightColor: lightColor,
                    offset: offset,
                    blurSigma: blurSigma,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KkInnerShadowPainter extends CustomPainter {
  const KkInnerShadowPainter({
    required this.borderRadius,
    required this.darkColor,
    required this.lightColor,
    required this.offset,
    required this.blurSigma,
  });

  final double borderRadius;
  final Color darkColor;
  final Color lightColor;
  final Offset offset;
  final double blurSigma;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final bounds = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(borderRadius),
    );

    canvas
      ..save()
      ..clipRRect(shape);
    _paintShadow(canvas, shape, darkColor, offset);
    _paintShadow(canvas, shape, lightColor, -offset);
    canvas.restore();
  }

  void _paintShadow(
    Canvas canvas,
    RRect shape,
    Color color,
    Offset shadowOffset,
  ) {
    final overflow = blurSigma * 4 + shadowOffset.distance;
    final outer = shape.outerRect.inflate(overflow);
    final shadowPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(outer)
      ..addRRect(shape.shift(shadowOffset));
    final paint = Paint()
      ..color = color
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blurSigma);

    canvas.drawPath(shadowPath, paint);
  }

  @override
  bool shouldRepaint(covariant KkInnerShadowPainter oldDelegate) {
    return borderRadius != oldDelegate.borderRadius ||
        darkColor != oldDelegate.darkColor ||
        lightColor != oldDelegate.lightColor ||
        offset != oldDelegate.offset ||
        blurSigma != oldDelegate.blurSigma;
  }
}
