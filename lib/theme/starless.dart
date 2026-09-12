// Defines Beyond's concrete themes, typography, colors, and shared geometry.
// Used by the app shell and themed editor widgets.

import 'package:beyond/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

// ---------- Palette and geometry ----------

const _starlessLightColors = BColors(
  canvasBackground: Color(0xfffbf9f7),
  canvasGrid: Color(0xffded7d2),
  surface: Color(0xffffffff),
  surfaceRaised: Color(0xfffffefd),
  surfaceSubtle: Color(0xfff7f3f0),
  surfaceHover: Color(0xfff8f4f1),
  surfacePressed: Color(0xfff2ece8),
  textPrimary: Color(0xff201c1a),
  textSecondary: Color(0xff655a53),
  textMuted: Color(0xff887b73),
  border: Color(0xffded7d2),
  borderSubtle: Color(0xffeae3de),
  accent: Color(0xffc66b53),
  accentHover: Color(0xffae5742),
  accentPressed: Color(0xff914534),
  accentSoft: Color(0xfffdf4f1),
  accentSubtle: Color(0xfff9e4de),
  focusRing: Color(0xffe5a48f),
  shadow: Color(0x1f302a27),
  scrim: Color(0x52201c1a),
);

const _starlessGeo = BGeo(
  radiusSmall: BorderRadius.all(Radius.circular(4)),
  radiusMedium: BorderRadius.all(Radius.circular(8)),
  radiusLarge: BorderRadius.all(Radius.circular(10)),
  elevationLow: 4,
  elevationMedium: 8,
  elevationHigh: 12,
);

// ---------- Typography ----------

var _useMonoFallback = false;

BTypo _starlessTypo(BColors colors) => BTypo(
  display: GoogleFonts.sourceSerif4(
    textStyle: const TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w600,
      height: 1.1,
    ),
    color: colors.textPrimary,
  ),
  heading: GoogleFonts.sourceSerif4(
    textStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    color: colors.textPrimary,
  ),
  title: GoogleFonts.robotoMono(
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    color: colors.textPrimary,
  ),
  body: GoogleFonts.robotoMono(
    textStyle: const TextStyle(fontSize: 13),
    color: colors.textPrimary,
  ),
  label: GoogleFonts.robotoMono(
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    color: colors.textPrimary,
  ),
  code: _useMonoFallback
      ? TextStyle(
          color: colors.textPrimary,
          fontFamily: 'monospace',
          fontSize: 14,
          height: 1.4,
        )
      : GoogleFonts.jetBrainsMono(
          color: colors.textPrimary,
          fontSize: 14,
          height: 1.4,
        ),
);

/// Loads runtime font families and enables a safe monospace fallback.
/// Called during application bootstrap before the root widget is mounted.
Future<void> loadFonts() async {
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.sourceSerif4(),
      GoogleFonts.robotoMono(),
      GoogleFonts.jetBrainsMono(),
      GoogleFonts.inter(),
    ]).timeout(const Duration(seconds: 3));
  } on Exception {
    _useMonoFallback = true;
  }
}

// ---------- Theme instances ----------

final ThemeData starlessLightThemeData = _starlessThemeData();

// ---------- Theme construction ----------

ThemeData _starlessThemeData() {
  const colors = _starlessLightColors;
  final typo = _starlessTypo(colors);
  final theme = BTheme(
    colors: colors,
    typo: typo,
    geo: _starlessGeo,
    syntaxTheme: atomOneLightTheme,
  );
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: colors.accent,
    onPrimary: colors.surface,
    primaryContainer: colors.accentSoft,
    onPrimaryContainer: colors.accentPressed,
    primaryFixed: colors.accentSoft,
    primaryFixedDim: colors.accentSubtle,
    onPrimaryFixed: colors.accentPressed,
    onPrimaryFixedVariant: colors.accentHover,
    secondary: colors.accent,
    onSecondary: colors.surface,
    secondaryContainer: colors.accentSoft,
    onSecondaryContainer: colors.accentPressed,
    secondaryFixed: colors.accentSoft,
    secondaryFixedDim: colors.accentSubtle,
    onSecondaryFixed: colors.accentPressed,
    onSecondaryFixedVariant: colors.accentHover,
    tertiary: colors.accent,
    onTertiary: colors.surface,
    tertiaryContainer: colors.accentSoft,
    onTertiaryContainer: colors.accentPressed,
    tertiaryFixed: colors.accentSoft,
    tertiaryFixedDim: colors.accentSubtle,
    onTertiaryFixed: colors.accentPressed,
    onTertiaryFixedVariant: colors.accentHover,
    error: colors.accentPressed,
    onError: colors.surface,
    errorContainer: colors.accentSoft,
    onErrorContainer: colors.accentPressed,
    surface: colors.surface,
    onSurface: colors.textPrimary,
    surfaceDim: colors.surfacePressed,
    surfaceBright: colors.surfaceRaised,
    surfaceContainerLowest: colors.surfaceRaised,
    surfaceContainerLow: colors.surface,
    surfaceContainer: colors.surfaceSubtle,
    surfaceContainerHigh: colors.surfaceHover,
    surfaceContainerHighest: colors.surfacePressed,
    onSurfaceVariant: colors.textSecondary,
    outline: colors.borderSubtle,
    outlineVariant: colors.borderSubtle,
    shadow: colors.shadow,
    scrim: colors.scrim,
    inverseSurface: colors.textPrimary,
    onInverseSurface: colors.surface,
    inversePrimary: colors.focusRing,
    surfaceTint: Colors.transparent,
  );

  return ThemeData(
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.canvasBackground,
    extensions: [theme],
    textTheme: TextTheme(
      displayLarge: typo.display,
      displayMedium: typo.display,
      displaySmall: typo.display.copyWith(fontSize: 28),
      headlineLarge: typo.heading,
      headlineMedium: typo.heading,
      headlineSmall: typo.heading,
      titleLarge: typo.title.copyWith(fontSize: 14),
      titleMedium: typo.title,
      titleSmall: typo.title,
      bodyLarge: typo.body.copyWith(fontSize: 14),
      bodyMedium: typo.body,
      bodySmall: typo.body.copyWith(fontSize: 12),
      labelLarge: typo.label,
      labelMedium: typo.label,
      labelSmall: typo.label,
    ),
    iconTheme: IconThemeData(color: colors.textSecondary),
    dividerTheme: DividerThemeData(color: colors.borderSubtle, thickness: 1),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accent,
      selectionColor: colors.accentSubtle,
      selectionHandleColor: colors.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: colors.textMuted),
    ),
    focusColor: colors.focusRing,
    hoverColor: colors.surfaceHover,
    splashColor: colors.surfacePressed,
    splashFactory: NoSplash.splashFactory,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.textPrimary,
      contentTextStyle: typo.body.copyWith(color: colors.surface),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.textPrimary,
        borderRadius: _starlessGeo.radiusSmall,
      ),
      textStyle: typo.body.copyWith(
        color: colors.surface,
        fontSize: 12,
      ),
    ),
  );
}
