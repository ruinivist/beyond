// Provides Beyond's pressable icon control.
// Used by canvas controls that expose a click action.

import 'package:beyond/foundation/b_container.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';

// ---------- Widgets ----------

class BIconButton extends StatelessWidget {
  // ---------- Construction ----------

  const BIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selectedTooltip,
    this.selected = false,
    super.key,
  });

  final Widget icon;
  final String tooltip;
  final String? selectedTooltip;
  final VoidCallback onPressed;
  final bool selected;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final message = selected ? selectedTooltip ?? tooltip : tooltip;
    final theme = BTheme.of(context);
    final transformedIcon = Transform.translate(
      offset: selected ? const Offset(0, 1) : Offset.zero,
      child: icon,
    );
    return Tooltip(
      message: message,
      child: BContainer(
        selected: selected,
        child: Semantics(
          selected: selected,
          child: IconButton(
            onPressed: onPressed,
            icon: transformedIcon,
            iconSize: 18,
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
              fixedSize: const WidgetStatePropertyAll(Size.square(40)),
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
    );
  }
}
