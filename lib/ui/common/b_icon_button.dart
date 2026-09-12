// Provides Beyond's pressable icon control.
// Used by canvas controls that expose a click action.

import 'package:beyond/ui/common/b_container.dart';
import 'package:beyond/ui/theme.dart';
import 'package:flutter/material.dart';

// ---------- Widgets ----------

class BIconButton extends StatelessWidget {
  // ---------- Construction ----------

  const BIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: BContainer(
        child: IconButton(
          onPressed: onPressed,
          icon: icon,
          iconSize: BSizes.defaultIconSize,
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(
              theme.colors.textPrimary,
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return theme.colors.surfacePressed;
              }
              if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
                return theme.colors.surfaceHover;
              }
              return Colors.transparent;
            }),
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? BorderSide(color: theme.colors.focusRing, width: 2)
                  : BorderSide.none,
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: theme.geo.radiusMedium),
            ),
            fixedSize: const WidgetStatePropertyAll(BSizes.defaultIconButtonSize),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}
