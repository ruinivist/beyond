import 'package:flutter/material.dart';

@immutable
class BColors {
  const BColors({
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

  BColors lerp(BColors? other, double t) {
    if (other == null) return this;
    return BColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      surfacePressed: Color.lerp(surfacePressed, other.surfacePressed, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

@immutable
class BTypo {
  const BTypo({
    required this.display,
    required this.heading,
    required this.title,
    required this.body,
    required this.label,
    required this.code,
  });

  final TextStyle display;
  final TextStyle heading;
  final TextStyle title;
  final TextStyle body;
  final TextStyle label;
  final TextStyle code;

  BTypo lerp(BTypo? other, double t) {
    if (other == null) return this;
    return BTypo(
      display: TextStyle.lerp(display, other.display, t)!,
      heading: TextStyle.lerp(heading, other.heading, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      code: TextStyle.lerp(code, other.code, t)!,
    );
  }
}

@immutable
class BGeo {
  const BGeo({
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.elevationLow,
    required this.elevationMedium,
    required this.elevationHigh,
  });

  final BorderRadius radiusSmall;
  final BorderRadius radiusMedium;
  final BorderRadius radiusLarge;
  final double elevationLow;
  final double elevationMedium;
  final double elevationHigh;

  BGeo lerp(BGeo? other, double t) {
    if (other == null) return this;
    return BGeo(
      radiusSmall: BorderRadius.lerp(radiusSmall, other.radiusSmall, t)!,
      radiusMedium: BorderRadius.lerp(radiusMedium, other.radiusMedium, t)!,
      radiusLarge: BorderRadius.lerp(radiusLarge, other.radiusLarge, t)!,
      elevationLow: elevationLow + (other.elevationLow - elevationLow) * t,
      elevationMedium:
          elevationMedium + (other.elevationMedium - elevationMedium) * t,
      elevationHigh: elevationHigh + (other.elevationHigh - elevationHigh) * t,
    );
  }
}

@immutable
class BTheme extends ThemeExtension<BTheme> {
  const BTheme({required this.colors, required this.typo, required this.geo});

  final BColors colors;
  final BTypo typo;
  final BGeo geo;

  static BTheme of(BuildContext context) {
    final theme = Theme.of(context).extension<BTheme>();
    if (theme == null) {
      throw FlutterError(
        'BTheme.of() called without a BTheme extension in the nearest Theme.',
      );
    }
    return theme;
  }

  @override
  BTheme copyWith({BColors? colors, BTypo? typo, BGeo? geo}) {
    return BTheme(
      colors: colors ?? this.colors,
      typo: typo ?? this.typo,
      geo: geo ?? this.geo,
    );
  }

  @override
  BTheme lerp(covariant BTheme? other, double t) {
    if (other == null) return this;
    return BTheme(
      colors: colors.lerp(other.colors, t),
      typo: typo.lerp(other.typo, t),
      geo: geo.lerp(other.geo, t),
    );
  }
}
