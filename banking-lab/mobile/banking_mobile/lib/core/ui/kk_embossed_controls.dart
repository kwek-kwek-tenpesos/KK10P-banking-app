import 'package:banking_mobile/core/theme/kk_theme.dart';
import 'package:banking_mobile/core/ui/kk_inner_shadow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum KkEmbossedButtonVariant { primary, secondary, insetAccent }

class KkEmbossedButton extends StatefulWidget {
  const KkEmbossedButton({
    required this.onPressed,
    required this.label,
    super.key,
    this.icon,
    this.variant = KkEmbossedButtonVariant.secondary,
  });

  final VoidCallback? onPressed;
  final Widget label;
  final Widget? icon;
  final KkEmbossedButtonVariant variant;

  @override
  State<KkEmbossedButton> createState() => _KkEmbossedButtonState();
}

class _KkEmbossedButtonState extends State<KkEmbossedButton> {
  late final WidgetStatesController _statesController;

  @override
  void initState() {
    super.initState();
    _statesController = WidgetStatesController()..addListener(_handleState);
  }

  @override
  void dispose() {
    _statesController
      ..removeListener(_handleState)
      ..dispose();
    super.dispose();
  }

  void _handleState() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      setState(() {});
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = KkMaterialTokens.of(context);
    final enabled = widget.onPressed != null;
    final pressed = _statesController.value.contains(WidgetState.pressed);
    final focused = _statesController.value.contains(WidgetState.focused);
    final primary = widget.variant == KkEmbossedButtonVariant.primary;
    final insetAccent = widget.variant == KkEmbossedButtonVariant.insetAccent;
    final focusColor = primary ? tokens.onPrimary : tokens.primary;

    return AnimatedContainer(
      duration: KkMotion.press,
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(
        0,
        pressed && !insetAccent ? 2 : 0,
        0,
      ),
      decoration: BoxDecoration(
        gradient: primary
            ? enabled
                  ? pressed
                        ? tokens.primaryPressedGradient
                        : tokens.primaryGradient
                  : tokens.disabledGradient
            : insetAccent
            ? enabled
                  ? pressed
                        ? tokens.pressedGradient
                        : tokens.insetGradient
                  : tokens.disabledGradient
            : enabled
            ? tokens.raisedGradient
            : tokens.disabledGradient,
        borderRadius: BorderRadius.circular(KkRadius.small),
        border: focused ? Border.all(color: focusColor, width: 2) : null,
        boxShadow: enabled && !pressed && !insetAccent
            ? primary
                  ? tokens.primaryDepth
                  : tokens.controlDepth
            : const [],
      ),
      child: KkInnerShadow(
        visible: enabled && (pressed || insetAccent),
        borderRadius: KkRadius.small,
        darkColor: primary
            ? tokens.primaryDarkShadow
            : insetAccent
            ? pressed
                  ? tokens.innerDark.withAlpha(235)
                  : tokens.innerDark
            : tokens.innerDark,
        lightColor: primary
            ? tokens.primaryLightShadow
            : insetAccent
            ? pressed
                  ? tokens.innerLight.withAlpha(235)
                  : tokens.innerLight
            : tokens.innerLight,
        offset: insetAccent
            ? pressed
                  ? const Offset(5, 5)
                  : const Offset(3, 3)
            : const Offset(4, 4),
        blurSigma: primary
            ? 2
            : insetAccent && pressed
            ? 5
            : 3,
        child: primary
            ? _buildFilledButton(tokens)
            : insetAccent
            ? _buildTextButton(tokens)
            : _buildOutlinedButton(tokens),
      ),
    );
  }

  ButtonStyle _buttonStyle(KkMaterialTokens tokens) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: KkSpacing.md, vertical: KkSpacing.sm),
    ),
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return widget.variant == KkEmbossedButtonVariant.primary
            ? tokens.onPrimary.withAlpha(170)
            : tokens.textSecondary.withAlpha(150);
      }
      return widget.variant == KkEmbossedButtonVariant.primary
          ? tokens.onPrimary
          : widget.variant == KkEmbossedButtonVariant.insetAccent
          ? tokens.primary
          : tokens.primary;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return widget.variant == KkEmbossedButtonVariant.primary
            ? tokens.primary.withAlpha(8)
            : widget.variant == KkEmbossedButtonVariant.insetAccent
            ? tokens.primary.withAlpha(12)
            : tokens.primary.withAlpha(10);
      }
      return null;
    }),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    side: const WidgetStatePropertyAll(BorderSide.none),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(KkRadius.small)),
      ),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontWeight: FontWeight.w700),
    ),
  );

  Widget _buildFilledButton(KkMaterialTokens tokens) {
    if (widget.icon case final icon?) {
      return FilledButton.icon(
        statesController: _statesController,
        onPressed: widget.onPressed,
        style: _buttonStyle(tokens),
        icon: icon,
        label: widget.label,
      );
    }
    return FilledButton(
      statesController: _statesController,
      onPressed: widget.onPressed,
      style: _buttonStyle(tokens),
      child: widget.label,
    );
  }

  Widget _buildOutlinedButton(KkMaterialTokens tokens) {
    if (widget.icon case final icon?) {
      return OutlinedButton.icon(
        statesController: _statesController,
        onPressed: widget.onPressed,
        style: _buttonStyle(tokens),
        icon: icon,
        label: widget.label,
      );
    }
    return OutlinedButton(
      statesController: _statesController,
      onPressed: widget.onPressed,
      style: _buttonStyle(tokens),
      child: widget.label,
    );
  }

  Widget _buildTextButton(KkMaterialTokens tokens) {
    if (widget.icon case final icon?) {
      return TextButton.icon(
        statesController: _statesController,
        onPressed: widget.onPressed,
        style: _buttonStyle(tokens),
        icon: icon,
        label: widget.label,
      );
    }
    return TextButton(
      statesController: _statesController,
      onPressed: widget.onPressed,
      style: _buttonStyle(tokens),
      child: widget.label,
    );
  }
}

class KkFieldSurface extends StatelessWidget {
  const KkFieldSurface({
    required this.child,
    super.key,
    this.helperText,
    this.errorText,
  });

  final Widget child;
  final String? helperText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = KkMaterialTokens.of(context);
    final supportText = errorText ?? helperText;
    final supportStyle = errorText == null
        ? theme.inputDecorationTheme.helperStyle ??
              theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )
        : theme.inputDecorationTheme.errorStyle ??
              theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              );
    final fieldTheme = errorText == null
        ? theme
        : theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(KkRadius.small),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(KkRadius.small),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 2,
                ),
              ),
            ),
          );

    return Semantics(
      container: true,
      liveRegion: errorText != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: tokens.raisedGradient,
              borderRadius: BorderRadius.circular(KkRadius.small),
              boxShadow: tokens.controlDepth,
            ),
            child: Theme(data: fieldTheme, child: child),
          ),
          if (supportText != null) ...[
            const SizedBox(height: KkSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KkSpacing.md),
              child: Text(supportText, style: supportStyle),
            ),
          ],
        ],
      ),
    );
  }
}

class KkIconTile extends StatelessWidget {
  const KkIconTile({required this.icon, super.key, this.size = 32});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = KkMaterialTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: tokens.raisedGradient,
        borderRadius: BorderRadius.circular(KkRadius.small),
        boxShadow: tokens.tileDepth,
      ),
      child: Padding(
        padding: const EdgeInsets.all(KkSpacing.sm),
        child: Icon(icon, size: size, color: tokens.primary),
      ),
    );
  }
}
