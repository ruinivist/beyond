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

@immutable
class AppSemanticColors {
  const AppSemanticColors({
    required this.canvasBackground,
    required this.canvasGrid,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSubtle,
    required this.surfaceHover,
    required this.surfacePressed,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderSubtle,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.accentSoft,
    required this.accentSubtle,
    required this.focusRing,
    required this.shadow,
    required this.scrim,
  });

  final Color canvasBackground;
  final Color canvasGrid;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSubtle;
  final Color surfaceHover;
  final Color surfacePressed;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderSubtle;
  final Color accent;
  final Color accentHover;
  final Color accentPressed;
  final Color accentSoft;
  final Color accentSubtle;
  final Color focusRing;
  final Color shadow;
  final Color scrim;
}

@immutable
class AppTypography {
  const AppTypography({
    required this.ui,
    required this.editorial,
    required this.mono,
  });

  final TextTheme ui;
  final TextTheme editorial;
  final TextStyle mono;
}

const _compactUiTextTheme = TextTheme(
  displayLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  displayMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  displaySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  headlineLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  headlineMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  headlineSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  titleLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  titleMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  bodyLarge: TextStyle(fontSize: 14),
  bodyMedium: TextStyle(fontSize: 13),
  bodySmall: TextStyle(fontSize: 12),
  labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
);

const _editorialTextTheme = TextTheme(
  displayLarge: TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w600,
    height: 1.1,
  ),
  displayMedium: TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.15,
  ),
  displaySmall: TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
  ),
  headlineLarge: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
  ),
  headlineMedium: TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.25,
  ),
  headlineSmall: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  ),
  titleLarge: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
  ),
  titleMedium: TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.35,
  ),
  titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
  bodyLarge: TextStyle(fontSize: 18, height: 1.5),
  bodyMedium: TextStyle(fontSize: 16, height: 1.5),
  bodySmall: TextStyle(fontSize: 14, height: 1.45),
  labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
);

typedef CanvasTokens = ({
  Color background,
  Color grid,
  Color penStroke,
  double dotRadius,
  double gridSpacing,
});

typedef ToolbarTokens = ({
  Color background,
  Color border,
  Color foreground,
  Color hoverBackground,
  Color pressedBackground,
  Color selectedBackground,
  Color selectedForeground,
  Color selectedHoverForeground,
  Color selectedPressedForeground,
  Color focus,
  Color shadow,
  double elevation,
  double radius,
});

typedef BlockTokens = ({
  Color background,
  Color border,
  Color selectedBorder,
  Color foreground,
  Color secondaryForeground,
  Color mutedForeground,
  Color divider,
  Color hoverBackground,
  Color pressedBackground,
  Color focus,
  Color shadow,
  double elevation,
  double radius,
  double selectedElevation,
});

typedef CodeEditorTokens = ({
  Color background,
  Color gutterBackground,
  Color foreground,
  Color mutedForeground,
  Color divider,
  Color cursor,
  Color cursorLine,
  Color selection,
  Color dropdownBackground,
  Map<String, TextStyle> syntaxTheme,
});

typedef SettingsTokens = ({
  Color background,
  Color navigationBackground,
  Color selectedBackground,
  Color hoverBackground,
  Color pressedBackground,
  Color foreground,
  Color secondaryForeground,
  Color selectedForeground,
  Color divider,
  Color focus,
  Color shadow,
  Color scrim,
  double elevation,
  double radius,
});

@immutable
class AppComponentTokens {
  const AppComponentTokens({
    required this.canvas,
    required this.toolbar,
    required this.block,
    required this.codeEditor,
    required this.settings,
  });

  factory AppComponentTokens.from(AppSemanticColors colors) {
    return AppComponentTokens(
      canvas: (
        background: colors.canvasBackground,
        grid: colors.canvasGrid,
        penStroke: colors.accent,
        dotRadius: 2,
        gridSpacing: 50,
      ),
      toolbar: (
        background: colors.surfaceRaised,
        border: colors.borderSubtle,
        foreground: colors.textSecondary,
        hoverBackground: colors.surfaceHover,
        pressedBackground: colors.surfacePressed,
        selectedBackground: colors.accentSoft,
        selectedForeground: colors.accent,
        selectedHoverForeground: colors.accentHover,
        selectedPressedForeground: colors.accentPressed,
        focus: colors.focusRing,
        shadow: colors.shadow,
        elevation: 4,
        radius: 8,
      ),
      block: (
        background: colors.surface,
        border: colors.borderSubtle,
        selectedBorder: colors.accent,
        foreground: colors.textPrimary,
        secondaryForeground: colors.textSecondary,
        mutedForeground: colors.textMuted,
        divider: colors.borderSubtle,
        hoverBackground: colors.surfaceHover,
        pressedBackground: colors.surfacePressed,
        focus: colors.focusRing,
        shadow: colors.shadow,
        elevation: 8,
        radius: 10,
        selectedElevation: 12,
      ),
      codeEditor: (
        background: colors.surface,
        gutterBackground: colors.surfaceSubtle,
        foreground: colors.textPrimary,
        mutedForeground: colors.textMuted,
        divider: colors.borderSubtle,
        cursor: colors.accent,
        cursorLine: colors.accentSoft,
        selection: colors.accentSubtle,
        dropdownBackground: colors.surfaceRaised,
        syntaxTheme: atomOneLightTheme,
      ),
      settings: (
        background: colors.surfaceRaised,
        navigationBackground: colors.surface,
        selectedBackground: colors.accentSoft,
        hoverBackground: colors.surfaceHover,
        pressedBackground: colors.surfacePressed,
        foreground: colors.textPrimary,
        secondaryForeground: colors.textSecondary,
        selectedForeground: colors.accent,
        divider: colors.borderSubtle,
        focus: colors.focusRing,
        shadow: colors.shadow,
        scrim: colors.scrim,
        elevation: 8,
        radius: 10,
      ),
    );
  }

  final CanvasTokens canvas;
  final ToolbarTokens toolbar;
  final BlockTokens block;
  final CodeEditorTokens codeEditor;
  final SettingsTokens settings;
}

@immutable
class AppTheme extends ThemeExtension<AppTheme> {
  const AppTheme({
    required this.colors,
    required this.components,
    required this.typography,
  });

  final AppSemanticColors colors;
  final AppComponentTokens components;
  final AppTypography typography;

  @override
  AppTheme copyWith({
    AppSemanticColors? colors,
    AppComponentTokens? components,
    AppTypography? typography,
  }) {
    return AppTheme(
      colors: colors ?? this.colors,
      components: components ?? this.components,
      typography: typography ?? this.typography,
    );
  }

  @override
  AppTheme lerp(covariant AppTheme? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppThemeContext on BuildContext {
  AppTheme get appTheme => Theme.of(this).extension<AppTheme>()!;
}

const _starlessLightColors = AppSemanticColors(
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
  color: _starlessLightColors.textPrimary,
  fontSize: 14,
  height: 1.4,
);

final _starlessLightTypography = AppTypography(
  ui: GoogleFonts.interTextTheme(_compactUiTextTheme).apply(
    bodyColor: _starlessLightColors.textPrimary,
    displayColor: _starlessLightColors.textPrimary,
  ),
  editorial: GoogleFonts.sourceSerif4TextTheme(_editorialTextTheme).apply(
    bodyColor: _starlessLightColors.textPrimary,
    displayColor: _starlessLightColors.textPrimary,
  ),
  mono: _useMonoFallback
      ? const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.4)
      : _ibmPlexMono(),
);

final starlessLight = AppTheme(
  colors: _starlessLightColors,
  components: AppComponentTokens.from(_starlessLightColors),
  typography: _starlessLightTypography,
);

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
  scaffoldBackgroundColor: _starlessLightColors.canvasBackground,
  extensions: [starlessLight],
  textTheme: starlessLight.typography.ui,
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
    contentTextStyle: starlessLight.typography.ui.bodyMedium!.copyWith(
      color: _Palette.white,
    ),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: _Palette.text,
      borderRadius: BorderRadius.circular(4),
    ),
    textStyle: starlessLight.typography.ui.bodySmall!.copyWith(
      color: _Palette.white,
    ),
  ),
);
