// Provides a themed raised surface for grouped controls.
// Used by floating editor controls and tool option panels.

import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ---------- Widgets ----------

class ControlSurface extends StatelessWidget {
  // ---------- Construction ----------

  const ControlSurface({
    required this.child,
    this.selected = false,
    super.key,
  });

  final Widget child;
  final bool selected;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    return Material(
      color: selected ? colors.surfacePressed : colors.surfaceRaised,
      elevation: selected ? 0 : theme.geo.elevationLow,
      shadowColor: colors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: theme.geo.radiusLarge,
        side: BorderSide(color: colors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Renders a pressable icon on a floating control surface.
/// Used by canvas controls that expose a click action.
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
      child: ControlSurface(
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

/// Renders a draggable icon on a floating control surface.
/// Used by canvas controls that start pointer transformations.
class BIconDrag extends StatelessWidget {
  // ---------- Construction ----------

  const BIconDrag({
    required this.icon,
    required this.tooltip,
    required this.onDragStart,
    super.key,
  });

  final Widget icon;
  final String tooltip;
  final GestureMultiDragStartCallback onDragStart;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ControlSurface(
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Semantics(
            button: true,
            label: tooltip,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                ImmediateMultiDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
                      ImmediateMultiDragGestureRecognizer.new,
                      (recognizer) => recognizer.onStart = onDragStart,
                    ),
              },
              child: SizedBox.square(
                dimension: 40,
                child: Center(
                  child: IconTheme.merge(
                    data: const IconThemeData(size: 18),
                    child: icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
