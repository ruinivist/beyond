import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../foundation/theme.dart';

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

const starlessCanvasBackground = _Palette.canvas;
const starlessCanvasGrid = _Palette.grid;

const starlessLightColors = BColors(
  surface: _Palette.white,
  surfaceRaised: _Palette.raised,
  surfaceSubtle: _Palette.subtle,
  surfaceHover: _Palette.hover,
  surfacePressed: _Palette.pressed,
  textPrimary: _Palette.text,
  textSecondary: _Palette.secondaryText,
  textMuted: _Palette.mutedText,
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

TextStyle _ibmPlexMono() => GoogleFonts.ibmPlexMono(
  color: starlessLightColors.textPrimary,
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
    color: starlessLightColors.textPrimary,
  ),
  heading: GoogleFonts.sourceSerif4(
    textStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    color: starlessLightColors.textPrimary,
  ),
  title: GoogleFonts.robotoMono(
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    color: starlessLightColors.textPrimary,
  ),
  body: GoogleFonts.robotoMono(
    textStyle: const TextStyle(fontSize: 13),
    color: starlessLightColors.textPrimary,
  ),
  label: GoogleFonts.robotoMono(
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    color: starlessLightColors.textPrimary,
  ),
  code: _useMonoFallback
      ? const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.4)
      : _ibmPlexMono(),
);

const starlessLightGeo = BGeo(
  radiusSmall: BorderRadius.all(Radius.circular(4)),
  radiusMedium: BorderRadius.all(Radius.circular(8)),
  radiusLarge: BorderRadius.all(Radius.circular(10)),
  elevationLow: 4,
  elevationMedium: 8,
  elevationHigh: 12,
);

final starlessLight = BTheme(
  colors: starlessLightColors,
  typo: _starlessLightTypo,
  geo: starlessLightGeo,
);

final starlessSyntaxTheme = atomOneLightTheme;

Future<void> loadCodeFont() async {
  try {
    await GoogleFonts.pendingFonts([
      _ibmPlexMono(),
    ]).timeout(const Duration(seconds: 3));
  } on Exception {
    _useMonoFallback = true;
  }
}

final starlessLightThemeData = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: starlessCanvasBackground,
  extensions: [starlessLight],
  textTheme: TextTheme(
    displaySmall: starlessLight.typo.display.copyWith(fontSize: 28),
    headlineSmall: starlessLight.typo.heading,
    titleLarge: starlessLight.typo.title.copyWith(fontSize: 14),
    titleMedium: starlessLight.typo.title,
    bodyLarge: starlessLight.typo.body.copyWith(fontSize: 14),
    bodyMedium: starlessLight.typo.body,
    bodySmall: starlessLight.typo.body.copyWith(fontSize: 12),
    labelLarge: starlessLight.typo.label,
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
  snackBarTheme: SnackBarThemeData(
    backgroundColor: _Palette.text,
    contentTextStyle: starlessLight.typo.body.copyWith(color: _Palette.white),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: _Palette.text,
      borderRadius: starlessLight.geo.radiusSmall,
    ),
    textStyle: starlessLight.typo.body.copyWith(
      color: _Palette.white,
      fontSize: 12,
    ),
  ),
);
