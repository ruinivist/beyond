// Provides the canvas toolbar's button styles and sizing.
// Used by toolbar actions and tool option buttons.

import 'package:beyond/theme/theme.dart';
import 'package:flutter/material.dart';

// ---------- Widgets ----------

class ToolbarButton extends StatelessWidget {
  // ---------- Construction ----------

  const ToolbarButton({
    required this.onPressed,
    required this.child,
    required this.selected,
    this.compact = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool selected;
  final bool compact;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
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
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          minimumSize: WidgetStatePropertyAll(
            compact ? Size.zero : const Size(88, 48),
          ),
          fixedSize: compact ? const WidgetStatePropertyAll(BSizes.defaultIconButtonSize) : null,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: IconTheme.merge(
          data: const IconThemeData(size: 16),
          child: child,
        ),
      ),
    );
  }
}
