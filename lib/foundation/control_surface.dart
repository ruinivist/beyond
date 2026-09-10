// Provides a themed raised surface for grouped controls.
// Used by floating editor controls and tool option panels.

import 'package:beyond/foundation/theme.dart';
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
