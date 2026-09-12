// Provides Beyond's semantic button variants and sizing behavior.
// Used throughout editor toolbars, dialogs, and controls.

import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';

// ---------- Types ----------

enum ButtonVariant { secondary, toolbar }

enum ButtonSize { medium, toolbar, icon }

// ---------- Widgets ----------

/// Renders a semantic Beyond button from a variant and size.
/// Used as the shared button primitive across editor surfaces.
class BButton extends StatelessWidget {
  // ---------- Construction ----------

  const BButton({
    required this.onPressed,
    required this.child,
    this.variant = ButtonVariant.secondary,
    this.size = ButtonSize.medium,
    this.selected,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool? selected;

  // ---------- Size resolution ----------

  double get _height => switch (size) {
    ButtonSize.medium => 40,
    ButtonSize.toolbar => 48,
    ButtonSize.icon => 40,
  };

  double get _horizontalPadding => switch (size) {
    ButtonSize.medium || ButtonSize.toolbar => 20,
    ButtonSize.icon => 0,
  };

  double get _verticalPadding => switch (size) {
    ButtonSize.medium || ButtonSize.toolbar => 8,
    ButtonSize.icon => 0,
  };

  double get _iconSize => switch (size) {
    ButtonSize.medium || ButtonSize.toolbar => 16,
    ButtonSize.icon => 18,
  };

  // ---------- Color resolution ----------

  Color _foreground(BColors colors) => switch (variant) {
    ButtonVariant.secondary => colors.textPrimary,
    ButtonVariant.toolbar => selected == true ? colors.accent : colors.textSecondary,
  };

  Color _background(BColors colors) => switch (variant) {
    ButtonVariant.secondary => colors.surfaceSubtle,
    ButtonVariant.toolbar => selected == true ? colors.surfacePressed : Colors.transparent,
  };

  // ---------- Composition ----------

  ButtonStyle _style(
    BColors colors,
    TextStyle textStyle,
    BorderRadius borderRadius,
  ) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled) ? colors.textMuted : _foreground(colors);
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return colors.surfacePressed;
        if (states.contains(WidgetState.pressed)) {
          return colors.surfacePressed;
        }
        if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
          return colors.surfaceHover;
        }
        return _background(colors);
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: colors.focusRing, width: 2);
        }
        return BorderSide.none;
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      textStyle: WidgetStatePropertyAll(textStyle),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
      ),
      minimumSize: WidgetStatePropertyAll(
        Size(size == ButtonSize.toolbar ? 88 : 0, _height),
      ),
      fixedSize: size == ButtonSize.icon ? WidgetStatePropertyAll(Size.square(_height)) : null,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final button = TextButton(
      onPressed: onPressed,
      style: _style(theme.colors, theme.typo.body, theme.geo.radiusMedium),
      child: IconTheme.merge(
        data: IconThemeData(size: _iconSize),
        child: child,
      ),
    );
    return selected == null ? button : Semantics(selected: selected, child: button);
  }
}
