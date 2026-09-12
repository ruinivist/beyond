// Provides the canvas toolbar's button styles and sizing.
// Used by toolbar actions and compact tool option buttons.

import 'package:beyond/ui/theme.dart';
import 'package:flutter/material.dart';

// ---------- Widgets ----------

class ToolbarButton extends StatelessWidget {
  // ---------- Construction ----------

  const ToolbarButton({
    required this.onPressed,
    required this.child,
    required this.selected,
    this.iconOnly = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool selected;
  final bool iconOnly;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final height = iconOnly ? 40.0 : 48.0;
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? theme.colors.textMuted
                : selected
                ? theme.colors.accent
                : theme.colors.textSecondary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled) || states.contains(WidgetState.pressed)) {
              return theme.colors.surfacePressed;
            }
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
              return theme.colors.surfaceHover;
            }
            return selected ? theme.colors.surfacePressed : Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: theme.colors.focusRing, width: 2)
                : BorderSide.none,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: theme.geo.radiusMedium),
          ),
          textStyle: WidgetStatePropertyAll(theme.typo.body),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: iconOnly ? 0 : 20,
              vertical: iconOnly ? 0 : 8,
            ),
          ),
          minimumSize: WidgetStatePropertyAll(Size(iconOnly ? 0 : 88, height)),
          fixedSize: iconOnly ? WidgetStatePropertyAll(Size.square(height)) : null,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: IconTheme.merge(
          data: IconThemeData(size: iconOnly ? 18 : 16),
          child: child,
        ),
      ),
    );
  }
}
