import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_inner_shadow.dart';
import 'package:flutter/material.dart';

enum KkSurfaceStyle { raised, inset, flat }

class KkSoftSurface extends StatelessWidget {
  const KkSoftSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(KkSpacing.lg),
    this.style = KkSurfaceStyle.raised,
    this.borderRadius = KkRadius.medium,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final KkSurfaceStyle style;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = KkMaterialTokens.of(context);
    final radius = BorderRadius.circular(borderRadius);
    final face = DecoratedBox(
      decoration: BoxDecoration(
        color: style == KkSurfaceStyle.flat ? tokens.canvas : null,
        gradient: switch (style) {
          KkSurfaceStyle.raised => tokens.raisedGradient,
          KkSurfaceStyle.inset => tokens.insetGradient,
          KkSurfaceStyle.flat => null,
        },
        borderRadius: radius,
        border: style == KkSurfaceStyle.raised
            ? Border.all(color: tokens.surfaceBorder, width: 0.75)
            : null,
      ),
      child: style == KkSurfaceStyle.inset
          ? KkInnerShadow(
              visible: true,
              borderRadius: borderRadius,
              darkColor: tokens.innerDark,
              lightColor: tokens.innerLight,
              offset: const Offset(5, 5),
              blurSigma: 8,
              child: Padding(padding: padding, child: child),
            )
          : Padding(padding: padding, child: child),
    );

    if (style != KkSurfaceStyle.raised) return face;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.canvas,
        borderRadius: radius,
        boxShadow: tokens.panelDepth,
      ),
      child: face,
    );
  }
}
