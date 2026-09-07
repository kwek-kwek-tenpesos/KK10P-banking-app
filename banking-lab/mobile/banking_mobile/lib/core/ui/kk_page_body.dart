import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:flutter/material.dart';

class KkPageBody extends StatelessWidget {
  const KkPageBody({
    required this.child,
    super.key,
    this.maxWidth = 440,
    this.padding = const EdgeInsets.all(KkSpacing.lg),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}
