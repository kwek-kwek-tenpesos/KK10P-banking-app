import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Legacy light-palette aliases kept while existing screens move to the
/// theme-aware material tokens one slice at a time.
abstract final class KkColors {
  static const background = Color(0xFFECEDE9);
  static const surface = background;
  static const raisedSurface = Color(0xFFE5E6E2);
  static const primary = Color(0xFF2563EB);
  static const navy = Color(0xFF0F172A);
  static const accent = primary;
  static const action = primary;
  static const actionShade = Color(0xFF1E40AF);
  static const lightShadow = Color(0xFFFFFFFF);
  static const darkShadow = Color(0xFF9EA3A1);
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
    required this.primaryPressedStart,
    required this.primaryPressedEnd,
    required this.primaryLightShadow,
    required this.primaryDarkShadow,
    required this.onPrimary,
    required this.surfaceBorder,
    required this.lightShadow,
    required this.darkShadow,
    required this.panelDepth,
    required this.controlDepth,
    required this.tileDepth,
    required this.innerDark,
    required this.innerLight,
  });

  static const light = KkMaterialTokens(
    canvas: Color(0xFFECEDE9),
    surfaceStart: Color(0xFFF7F7F3),
    surfaceEnd: Color(0xFFE5E6E2),
    insetStart: Color(0xFFF0F1ED),
    insetEnd: Color(0xFFF0F1ED),
    pressedStart: Color(0xFFCDD1CE),
    pressedEnd: Color(0xFFE8EAE6),
    disabledStart: Color(0xFFE1E3DF),
    disabledEnd: Color(0xFFD7DAD6),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    primary: Color(0xFF2563EB),
    primaryShade: Color(0xFF1E40AF),
    onPrimary: Colors.white,
    primaryPressedStart: Color(0xFF1D4EB8),
    primaryPressedEnd: Color(0xFF3979F2),
    primaryLightShadow: Color(0x805B8FF5),
    primaryDarkShadow: Color(0x70173889),
    surfaceBorder: Color(0xD9FFFFFF),
    lightShadow: Color(0xF2FFFFFF),
    darkShadow: Color(0x809EA3A1),
    panelDepth: [
      BoxShadow(
        color: Color(0xF2FFFFFF),
        offset: Offset(-7, -7),
        blurRadius: 14,
      ),
      BoxShadow(color: Color(0x809EA3A1), offset: Offset(6, 6), blurRadius: 8),
    ],
    controlDepth: [
      BoxShadow(
        color: Color(0xE6FFFFFF),
        offset: Offset(-5, -5),
        blurRadius: 10,
      ),
      BoxShadow(color: Color(0x739EA3A1), offset: Offset(5, 5), blurRadius: 2),
    ],
    tileDepth: [
      BoxShadow(
        color: Color(0xD9FFFFFF),
        offset: Offset(-4, -4),
        blurRadius: 2,
      ),
      BoxShadow(color: Color(0x669EA3A1), offset: Offset(4, 4), blurRadius: 4),
    ],
    innerDark: Color(0xA69EA3A1),
    innerLight: Color(0xD9FFFFFF),
  );

  static const dark = KkMaterialTokens(
    canvas: Color(0xFF22262B),
    surfaceStart: Color(0xFF2D333B),
    surfaceEnd: Color(0xFF282D34),
    insetStart: Color(0xFF2A3037),
    insetEnd: Color(0xFF2A3037),
    pressedStart: Color(0xFF15181C),
    pressedEnd: Color(0xFF282E35),
    disabledStart: Color(0xFF292E35),
    disabledEnd: Color(0xFF22272D),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFCBD5E1),
    primary: Color(0xFF60A5FA),
    primaryShade: Color(0xFF2563EB),
    primaryPressedStart: Color(0xFF2B64B7),
    primaryPressedEnd: Color(0xFF5A9AEF),
    primaryLightShadow: Color(0x70578FDD),
    primaryDarkShadow: Color(0x80142445),
    onPrimary: Color(0xFF07111F),
    surfaceBorder: Color(0x80515A65),
    lightShadow: Color(0x4D56606B),
    darkShadow: Color(0x990E1115),
    panelDepth: [
      BoxShadow(
        color: Color(0x4D56606B),
        offset: Offset(-6, -6),
        blurRadius: 12,
      ),
      BoxShadow(color: Color(0x990E1115), offset: Offset(6, 6), blurRadius: 12),
    ],
    controlDepth: [
      BoxShadow(
        color: Color(0x4056606B),
        offset: Offset(-4, -4),
        blurRadius: 8,
      ),
      BoxShadow(color: Color(0x8C0E1115), offset: Offset(4, 4), blurRadius: 8),
    ],
    tileDepth: [
      BoxShadow(
        color: Color(0x3856606B),
        offset: Offset(-3, -3),
        blurRadius: 6,
      ),
      BoxShadow(color: Color(0x800E1115), offset: Offset(3, 3), blurRadius: 6),
    ],
    innerDark: Color(0xBF0F1216),
    innerLight: Color(0x66545E69),
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
  final Color primaryPressedStart;
  final Color primaryPressedEnd;
  final Color primaryLightShadow;
  final Color primaryDarkShadow;
  final Color onPrimary;
  final Color surfaceBorder;
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

  LinearGradient get primaryPressedGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryPressedStart, primaryPressedEnd],
  );

  List<BoxShadow> get primaryDepth => [
    BoxShadow(
      color: primaryLightShadow,
      offset: const Offset(-1, -1),
      blurRadius: 5,
    ),
    BoxShadow(
      color: primaryDarkShadow,
      offset: const Offset(2, 2),
      blurRadius: 5,
    ),
  ];

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
    Color? primaryPressedStart,
    Color? primaryPressedEnd,
    Color? primaryLightShadow,
    Color? primaryDarkShadow,
    Color? onPrimary,
    Color? surfaceBorder,
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
      primaryPressedStart: primaryPressedStart ?? this.primaryPressedStart,
      primaryPressedEnd: primaryPressedEnd ?? this.primaryPressedEnd,
      primaryLightShadow: primaryLightShadow ?? this.primaryLightShadow,
      primaryDarkShadow: primaryDarkShadow ?? this.primaryDarkShadow,
      onPrimary: onPrimary ?? this.onPrimary,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
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
      primaryPressedStart: Color.lerp(
        primaryPressedStart,
        other.primaryPressedStart,
        t,
      )!,
      primaryPressedEnd: Color.lerp(
        primaryPressedEnd,
        other.primaryPressedEnd,
        t,
      )!,
      primaryLightShadow: Color.lerp(
        primaryLightShadow,
        other.primaryLightShadow,
        t,
      )!,
      primaryDarkShadow: Color.lerp(
        primaryDarkShadow,
        other.primaryDarkShadow,
        t,
      )!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
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
  static final primary = KkMaterialTokens.light.primaryDepth;
  static final raised = panel;
}

abstract final class KkGradients {
  static final panel = KkMaterialTokens.light.raisedGradient;
  static final control = KkMaterialTokens.light.raisedGradient;
  static final insetControl = KkMaterialTokens.light.insetGradient;
  static final insetPressed = KkMaterialTokens.light.pressedGradient;
  static final primaryAction = KkMaterialTokens.light.primaryGradient;
  static final primaryPressed = KkMaterialTokens.light.primaryPressedGradient;
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
