import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Legacy light-palette aliases kept while existing screens move to the
/// theme-aware material tokens one slice at a time.
abstract final class KkColors {
  static const background = Color(0xFFE8EEF6);
  static const surface = background;
  static const raisedSurface = Color(0xFFE3EAF3);
  static const primary = Color(0xFF2563EB);
  static const navy = Color(0xFF0F172A);
  static const accent = primary;
  static const action = primary;
  static const actionShade = Color(0xFF1E40AF);
  static const lightShadow = Color(0xFFFFFFFF);
  static const darkShadow = Color(0xFF9BAABC);
}

abstract final class KkMotion {
  static const press = Duration(milliseconds: 70);
}

abstract final class KkSpacing {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class KkRadius {
  static const small = 12.0;
  static const medium = 20.0;
  static const large = 28.0;
}

@immutable
class KkMaterialTokens extends ThemeExtension<KkMaterialTokens> {
  const KkMaterialTokens({
    required this.canvas,
    required this.surfaceStart,
    required this.surfaceEnd,
    required this.insetStart,
    required this.insetEnd,
    required this.pressedStart,
    required this.pressedEnd,
    required this.disabledStart,
    required this.disabledEnd,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.primaryShade,
    required this.onPrimary,
    required this.lightShadow,
    required this.darkShadow,
    required this.panelDepth,
    required this.controlDepth,
    required this.tileDepth,
    required this.innerDark,
    required this.innerLight,
  });

  static const light = KkMaterialTokens(
    canvas: Color(0xFFE8EEF6),
    surfaceStart: Color(0xFFF1F5FA),
    surfaceEnd: Color(0xFFE1E9F2),
    insetStart: Color(0xFFD3DDE8),
    insetEnd: Color(0xFFEDF2F8),
    pressedStart: Color(0xFFCBD6E2),
    pressedEnd: Color(0xFFE4EBF3),
    disabledStart: Color(0xFFE0E7EF),
    disabledEnd: Color(0xFFD5DEE8),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    primary: Color(0xFF2563EB),
    primaryShade: Color(0xFF1E40AF),
    onPrimary: Colors.white,
    lightShadow: Color(0xF2FFFFFF),
    darkShadow: Color(0xB39BAABC),
    panelDepth: [
      BoxShadow(
        color: Color(0xF2FFFFFF),
        offset: Offset(-10, -10),
        blurRadius: 22,
      ),
      BoxShadow(
        color: Color(0xB39BAABC),
        offset: Offset(10, 10),
        blurRadius: 22,
      ),
    ],
    controlDepth: [
      BoxShadow(
        color: Color(0xF2FFFFFF),
        offset: Offset(-7, -7),
        blurRadius: 15,
      ),
      BoxShadow(color: Color(0xB39BAABC), offset: Offset(7, 7), blurRadius: 15),
    ],
    tileDepth: [
      BoxShadow(
        color: Color(0xF2FFFFFF),
        offset: Offset(-5, -5),
        blurRadius: 11,
      ),
      BoxShadow(color: Color(0xA69BAABC), offset: Offset(5, 5), blurRadius: 11),
    ],
    innerDark: Color(0xB39BAABC),
    innerLight: Color(0xE6FFFFFF),
  );

  static const dark = KkMaterialTokens(
    canvas: Color(0xFF202833),
    surfaceStart: Color(0xFF293440),
    surfaceEnd: Color(0xFF1C242E),
    insetStart: Color(0xFF151B22),
    insetEnd: Color(0xFF26313D),
    pressedStart: Color(0xFF11171E),
    pressedEnd: Color(0xFF222C37),
    disabledStart: Color(0xFF232D38),
    disabledEnd: Color(0xFF1B232C),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFCBD5E1),
    primary: Color(0xFF60A5FA),
    primaryShade: Color(0xFF2563EB),
    onPrimary: Color(0xFF07111F),
    lightShadow: Color(0xB33A4858),
    darkShadow: Color(0xD911171E),
    panelDepth: [
      BoxShadow(
        color: Color(0xB33A4858),
        offset: Offset(-10, -10),
        blurRadius: 22,
      ),
      BoxShadow(
        color: Color(0xD911171E),
        offset: Offset(10, 10),
        blurRadius: 22,
      ),
    ],
    controlDepth: [
      BoxShadow(
        color: Color(0xA63A4858),
        offset: Offset(-7, -7),
        blurRadius: 15,
      ),
      BoxShadow(color: Color(0xD911171E), offset: Offset(7, 7), blurRadius: 15),
    ],
    tileDepth: [
      BoxShadow(
        color: Color(0x993A4858),
        offset: Offset(-5, -5),
        blurRadius: 11,
      ),
      BoxShadow(color: Color(0xCC11171E), offset: Offset(5, 5), blurRadius: 11),
    ],
    innerDark: Color(0xE611171E),
    innerLight: Color(0x993A4858),
  );

  final Color canvas;
  final Color surfaceStart;
  final Color surfaceEnd;
  final Color insetStart;
  final Color insetEnd;
  final Color pressedStart;
  final Color pressedEnd;
  final Color disabledStart;
  final Color disabledEnd;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color primaryShade;
  final Color onPrimary;
  final Color lightShadow;
  final Color darkShadow;
  final List<BoxShadow> panelDepth;
  final List<BoxShadow> controlDepth;
  final List<BoxShadow> tileDepth;
  final Color innerDark;
  final Color innerLight;

  LinearGradient get raisedGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceStart, surfaceEnd],
  );

  LinearGradient get insetGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [insetStart, insetEnd],
  );

  LinearGradient get pressedGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pressedStart, pressedEnd],
  );

  LinearGradient get disabledGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [disabledStart, disabledEnd],
  );

  LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryShade],
  );

  static KkMaterialTokens of(BuildContext context) {
    return Theme.of(context).extension<KkMaterialTokens>() ?? light;
  }

  @override
  KkMaterialTokens copyWith({
    Color? canvas,
    Color? surfaceStart,
    Color? surfaceEnd,
    Color? insetStart,
    Color? insetEnd,
    Color? pressedStart,
    Color? pressedEnd,
    Color? disabledStart,
    Color? disabledEnd,
    Color? textPrimary,
    Color? textSecondary,
    Color? primary,
    Color? primaryShade,
    Color? onPrimary,
    Color? lightShadow,
    Color? darkShadow,
    List<BoxShadow>? panelDepth,
    List<BoxShadow>? controlDepth,
    List<BoxShadow>? tileDepth,
    Color? innerDark,
    Color? innerLight,
  }) {
    return KkMaterialTokens(
      canvas: canvas ?? this.canvas,
      surfaceStart: surfaceStart ?? this.surfaceStart,
      surfaceEnd: surfaceEnd ?? this.surfaceEnd,
      insetStart: insetStart ?? this.insetStart,
      insetEnd: insetEnd ?? this.insetEnd,
      pressedStart: pressedStart ?? this.pressedStart,
      pressedEnd: pressedEnd ?? this.pressedEnd,
      disabledStart: disabledStart ?? this.disabledStart,
      disabledEnd: disabledEnd ?? this.disabledEnd,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      primary: primary ?? this.primary,
      primaryShade: primaryShade ?? this.primaryShade,
      onPrimary: onPrimary ?? this.onPrimary,
      lightShadow: lightShadow ?? this.lightShadow,
      darkShadow: darkShadow ?? this.darkShadow,
      panelDepth: panelDepth ?? this.panelDepth,
      controlDepth: controlDepth ?? this.controlDepth,
      tileDepth: tileDepth ?? this.tileDepth,
      innerDark: innerDark ?? this.innerDark,
      innerLight: innerLight ?? this.innerLight,
    );
  }

  @override
  KkMaterialTokens lerp(
    covariant ThemeExtension<KkMaterialTokens>? other,
    double t,
  ) {
    if (other is! KkMaterialTokens) return this;
    return KkMaterialTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceStart: Color.lerp(surfaceStart, other.surfaceStart, t)!,
      surfaceEnd: Color.lerp(surfaceEnd, other.surfaceEnd, t)!,
      insetStart: Color.lerp(insetStart, other.insetStart, t)!,
      insetEnd: Color.lerp(insetEnd, other.insetEnd, t)!,
      pressedStart: Color.lerp(pressedStart, other.pressedStart, t)!,
      pressedEnd: Color.lerp(pressedEnd, other.pressedEnd, t)!,
      disabledStart: Color.lerp(disabledStart, other.disabledStart, t)!,
      disabledEnd: Color.lerp(disabledEnd, other.disabledEnd, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryShade: Color.lerp(primaryShade, other.primaryShade, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      lightShadow: Color.lerp(lightShadow, other.lightShadow, t)!,
      darkShadow: Color.lerp(darkShadow, other.darkShadow, t)!,
      panelDepth: BoxShadow.lerpList(panelDepth, other.panelDepth, t)!,
      controlDepth: BoxShadow.lerpList(controlDepth, other.controlDepth, t)!,
      tileDepth: BoxShadow.lerpList(tileDepth, other.tileDepth, t)!,
      innerDark: Color.lerp(innerDark, other.innerDark, t)!,
      innerLight: Color.lerp(innerLight, other.innerLight, t)!,
    );
  }
}

/// Legacy light-only aliases for screens that have not entered the new slice.
abstract final class KkDepth {
  static final panel = KkMaterialTokens.light.panelDepth;
  static final control = KkMaterialTokens.light.controlDepth;
  static final tile = KkMaterialTokens.light.tileDepth;
  static final raised = panel;
}

abstract final class KkGradients {
  static final panel = KkMaterialTokens.light.raisedGradient;
  static final control = KkMaterialTokens.light.raisedGradient;
  static final insetControl = KkMaterialTokens.light.insetGradient;
  static final insetPressed = KkMaterialTokens.light.pressedGradient;
  static final primaryAction = KkMaterialTokens.light.primaryGradient;
  static final disabledControl = KkMaterialTokens.light.disabledGradient;
  static const disabledAction = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF93A4B8), Color(0xFF718096)],
  );
}

abstract final class KkTheme {
  static ThemeData light() => _build(KkMaterialTokens.light, Brightness.light);

  static ThemeData dark() => _build(KkMaterialTokens.dark, Brightness.dark);

  static ThemeData _build(KkMaterialTokens tokens, Brightness brightness) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: tokens.primary,
          brightness: brightness,
          primary: tokens.primary,
          surface: tokens.canvas,
        ).copyWith(
          onPrimary: tokens.onPrimary,
          onSurface: tokens.textPrimary,
          onSurfaceVariant: tokens.textSecondary,
        );
    final base = ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.canvas,
      useMaterial3: true,
      extensions: [tokens],
    );
    const roundedRectangle = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(KkRadius.small)),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: tokens.textPrimary,
        displayColor: tokens.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.canvas,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.canvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KkSpacing.md,
          vertical: KkSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KkRadius.small),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KkRadius.small),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KkRadius.small),
          borderSide: BorderSide(color: tokens.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KkRadius.small),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KkRadius.small),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: tokens.primary,
          foregroundColor: tokens.onPrimary,
          disabledBackgroundColor: tokens.primary.withAlpha(100),
          disabledForegroundColor: tokens.onPrimary.withAlpha(170),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: roundedRectangle,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: tokens.primary,
          side: BorderSide.none,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: roundedRectangle,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: tokens.primary,
          shape: roundedRectangle,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: tokens.primary,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.primary,
        linearTrackColor: tokens.insetStart,
      ),
      dividerTheme: DividerThemeData(color: tokens.darkShadow.withAlpha(80)),
    );
  }
}
