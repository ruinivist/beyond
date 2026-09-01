import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

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

const _starlessDarkColors = BColors(
  canvasBackground: Color(0xff171412),
  canvasGrid: Color(0xff403734),
  surface: Color(0xff211d1b),
  surfaceRaised: Color(0xff292421),
  surfaceSubtle: Color(0xff26211f),
  surfaceHover: Color(0xff302a27),
  surfacePressed: Color(0xff3a322e),
  textPrimary: Color(0xfff5efeb),
  textSecondary: Color(0xffc8bbb3),
  textMuted: Color(0xff9f9088),
  border: Color(0xff403733),
  borderSubtle: Color(0xff342d29),
  accent: Color(0xffdc8068),
  accentHover: Color(0xffe58f79),
  accentPressed: Color(0xffc56a53),
  accentSoft: Color(0xff35211c),
  accentSubtle: Color(0xff472820),
  focusRing: Color(0xffe5a48f),
  shadow: Color(0x80000000),
  scrim: Color(0xa6000000),
);

const _starlessGeo = BGeo(
  radiusSmall: BorderRadius.all(Radius.circular(4)),
  radiusMedium: BorderRadius.all(Radius.circular(8)),
  radiusLarge: BorderRadius.all(Radius.circular(10)),
  elevationLow: 4,
  elevationMedium: 8,
  elevationHigh: 12,
);

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

enum AppTheme {
  starlessLight,
  starlessDark;

  String get label => switch (this) {
    AppTheme.starlessLight => 'Starless Light',
    AppTheme.starlessDark => 'Starless Dark',
  };

  ThemeData get themeData => switch (this) {
    AppTheme.starlessLight => starlessLightThemeData,
    AppTheme.starlessDark => starlessDarkThemeData,
  };
}

final ThemeData starlessLightThemeData = _starlessThemeData(
  brightness: Brightness.light,
  colors: _starlessLightColors,
  syntaxTheme: atomOneLightTheme,
);

final ThemeData starlessDarkThemeData = _starlessThemeData(
  brightness: Brightness.dark,
  colors: _starlessDarkColors,
  syntaxTheme: atomOneDarkTheme,
);

ThemeData _starlessThemeData({
  required Brightness brightness,
  required BColors colors,
  required Map<String, TextStyle> syntaxTheme,
}) {
  final typo = _starlessTypo(colors);
  final theme = BTheme(
    colors: colors,
    typo: typo,
    geo: _starlessGeo,
    syntaxTheme: syntaxTheme,
  );
  final onAccent = brightness == Brightness.light
      ? colors.surface
      : colors.canvasBackground;
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: onAccent,
    primaryContainer: colors.accentSoft,
    onPrimaryContainer: colors.accentPressed,
    primaryFixed: colors.accentSoft,
    primaryFixedDim: colors.accentSubtle,
    onPrimaryFixed: colors.accentPressed,
    onPrimaryFixedVariant: colors.accentHover,
    secondary: colors.accent,
    onSecondary: onAccent,
    secondaryContainer: colors.accentSoft,
    onSecondaryContainer: colors.accentPressed,
    secondaryFixed: colors.accentSoft,
    secondaryFixedDim: colors.accentSubtle,
    onSecondaryFixed: colors.accentPressed,
    onSecondaryFixedVariant: colors.accentHover,
    tertiary: colors.accent,
    onTertiary: onAccent,
    tertiaryContainer: colors.accentSoft,
    onTertiaryContainer: colors.accentPressed,
    tertiaryFixed: colors.accentSoft,
    tertiaryFixedDim: colors.accentSubtle,
    onTertiaryFixed: colors.accentPressed,
    onTertiaryFixedVariant: colors.accentHover,
    error: colors.accentPressed,
    onError: onAccent,
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
    brightness: brightness,
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
