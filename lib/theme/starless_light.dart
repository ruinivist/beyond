import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

abstract final class _Palette {
  static const canvas = Color(0xfffbf9f7);
  static const grid = Color(0xffded7d2);
  static const white = Color(0xffffffff);
  static const raised = Color(0xfffffefd);
  static const subtle = Color(0xfff7f3f0);
  static const hover = Color(0xfff8f4f1);
  static const pressed = Color(0xfff2ece8);
  static const text = Color(0xff201c1a);
  static const secondaryText = Color(0xff655a53);
  static const mutedText = Color(0xff887b73);
  static const border = Color(0xffeae3de);
  static const rose50 = Color(0xfffdf4f1);
  static const rose100 = Color(0xfff9e4de);
  static const rose300 = Color(0xffe5a48f);
  static const rose500 = Color(0xffc66b53);
  static const rose600 = Color(0xffae5742);
  static const rose700 = Color(0xff914534);
  static const shadow = Color(0x1f302a27);
  static const scrim = Color(0x52201c1a);
}

const _starlessLightColors = BColors(
  canvasBackground: _Palette.canvas,
  canvasGrid: _Palette.grid,
  surface: _Palette.white,
  surfaceRaised: _Palette.raised,
  surfaceSubtle: _Palette.subtle,
  surfaceHover: _Palette.hover,
  surfacePressed: _Palette.pressed,
  textPrimary: _Palette.text,
  textSecondary: _Palette.secondaryText,
  textMuted: _Palette.mutedText,
  border: _Palette.grid,
  borderSubtle: _Palette.border,
  accent: _Palette.rose500,
  accentHover: _Palette.rose600,
  accentPressed: _Palette.rose700,
  accentSoft: _Palette.rose50,
  accentSubtle: _Palette.rose100,
  focusRing: _Palette.rose300,
  shadow: _Palette.shadow,
  scrim: _Palette.scrim,
);

var _useMonoFallback = false;

TextStyle _jetBrainsMono() => GoogleFonts.jetBrainsMono(
  color: _starlessLightColors.textPrimary,
  fontSize: 14,
  height: 1.4,
);

final _starlessLightTypo = BTypo(
  display: GoogleFonts.sourceSerif4(
    textStyle: const TextStyle(
      fontSize: 40,
      fontWeight: FontWeight.w600,
      height: 1.1,
    ),
    color: _starlessLightColors.textPrimary,
  ),
  heading: GoogleFonts.sourceSerif4(
    textStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    color: _starlessLightColors.textPrimary,
  ),
  title: GoogleFonts.robotoMono(
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    color: _starlessLightColors.textPrimary,
  ),
  body: GoogleFonts.robotoMono(
    textStyle: const TextStyle(fontSize: 13),
    color: _starlessLightColors.textPrimary,
  ),
  label: GoogleFonts.robotoMono(
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    color: _starlessLightColors.textPrimary,
  ),
  code: _useMonoFallback
      ? const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.4)
      : _jetBrainsMono(),
);

const _starlessLightGeo = BGeo(
  radiusSmall: BorderRadius.all(Radius.circular(4)),
  radiusMedium: BorderRadius.all(Radius.circular(8)),
  radiusLarge: BorderRadius.all(Radius.circular(10)),
  elevationLow: 4,
  elevationMedium: 8,
  elevationHigh: 12,
);

final _starlessLight = BTheme(
  colors: _starlessLightColors,
  typo: _starlessLightTypo,
  geo: _starlessLightGeo,
  syntaxTheme: atomOneLightTheme,
);

const _starlessLightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: _Palette.rose500,
  onPrimary: _Palette.white,
  primaryContainer: _Palette.rose50,
  onPrimaryContainer: _Palette.rose700,
  primaryFixed: _Palette.rose50,
  primaryFixedDim: _Palette.rose100,
  onPrimaryFixed: _Palette.rose700,
  onPrimaryFixedVariant: _Palette.rose600,
  secondary: _Palette.rose500,
  onSecondary: _Palette.white,
  secondaryContainer: _Palette.rose50,
  onSecondaryContainer: _Palette.rose700,
  secondaryFixed: _Palette.rose50,
  secondaryFixedDim: _Palette.rose100,
  onSecondaryFixed: _Palette.rose700,
  onSecondaryFixedVariant: _Palette.rose600,
  tertiary: _Palette.rose500,
  onTertiary: _Palette.white,
  tertiaryContainer: _Palette.rose50,
  onTertiaryContainer: _Palette.rose700,
  tertiaryFixed: _Palette.rose50,
  tertiaryFixedDim: _Palette.rose100,
  onTertiaryFixed: _Palette.rose700,
  onTertiaryFixedVariant: _Palette.rose600,
  error: _Palette.rose700,
  onError: _Palette.white,
  errorContainer: _Palette.rose50,
  onErrorContainer: _Palette.rose700,
  surface: _Palette.white,
  onSurface: _Palette.text,
  surfaceDim: _Palette.pressed,
  surfaceBright: _Palette.raised,
  surfaceContainerLowest: _Palette.raised,
  surfaceContainerLow: _Palette.white,
  surfaceContainer: _Palette.subtle,
  surfaceContainerHigh: _Palette.hover,
  surfaceContainerHighest: _Palette.pressed,
  onSurfaceVariant: _Palette.secondaryText,
  outline: _Palette.border,
  outlineVariant: _Palette.border,
  shadow: _Palette.shadow,
  scrim: _Palette.scrim,
  inverseSurface: _Palette.text,
  onInverseSurface: _Palette.white,
  inversePrimary: _Palette.rose300,
  surfaceTint: Colors.transparent,
);

Future<void> loadCodeFont() async {
  try {
    await GoogleFonts.pendingFonts([
      _jetBrainsMono(),
    ]).timeout(const Duration(seconds: 3));
  } on Exception {
    _useMonoFallback = true;
  }
}

final starlessLightThemeData = ThemeData(
  brightness: Brightness.light,
  colorScheme: _starlessLightColorScheme,
  scaffoldBackgroundColor: _starlessLight.colors.canvasBackground,
  extensions: [_starlessLight],
  textTheme: TextTheme(
    displayLarge: _starlessLight.typo.display,
    displayMedium: _starlessLight.typo.display,
    displaySmall: _starlessLight.typo.display.copyWith(fontSize: 28),
    headlineLarge: _starlessLight.typo.heading,
    headlineMedium: _starlessLight.typo.heading,
    headlineSmall: _starlessLight.typo.heading,
    titleLarge: _starlessLight.typo.title.copyWith(fontSize: 14),
    titleMedium: _starlessLight.typo.title,
    titleSmall: _starlessLight.typo.title,
    bodyLarge: _starlessLight.typo.body.copyWith(fontSize: 14),
    bodyMedium: _starlessLight.typo.body,
    bodySmall: _starlessLight.typo.body.copyWith(fontSize: 12),
    labelLarge: _starlessLight.typo.label,
    labelMedium: _starlessLight.typo.label,
    labelSmall: _starlessLight.typo.label,
  ),
  iconTheme: const IconThemeData(color: _Palette.secondaryText),
  dividerTheme: const DividerThemeData(color: _Palette.border, thickness: 1),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: _Palette.rose500,
    selectionColor: _Palette.rose100,
    selectionHandleColor: _Palette.rose500,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    hintStyle: TextStyle(color: _Palette.mutedText),
  ),
  focusColor: _Palette.rose300,
  hoverColor: _Palette.hover,
  splashColor: _Palette.pressed,
  splashFactory: NoSplash.splashFactory,
  snackBarTheme: SnackBarThemeData(
    backgroundColor: _Palette.text,
    contentTextStyle: _starlessLight.typo.body.copyWith(color: _Palette.white),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: _Palette.text,
      borderRadius: _starlessLight.geo.radiusSmall,
    ),
    textStyle: _starlessLight.typo.body.copyWith(
      color: _Palette.white,
      fontSize: 12,
    ),
  ),
);
