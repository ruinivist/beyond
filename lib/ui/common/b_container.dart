// Provides Beyond's themed surface container.
// Used by canvas editors, floating controls, and tool option panels.

import 'package:beyond/theme/theme.dart';
import 'package:flutter/material.dart';

// ---------- Widgets ----------

class BContainer extends StatelessWidget {
  // ---------- Construction ----------

  const BContainer({
    required this.child,
    this.selected = false,
    this.raised = true,
    super.key,
  });

  final Widget child;
  final bool selected;
  final bool raised;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    return Material(
      color: selected
          ? colors.accentSoft
          : raised
          ? colors.surfaceRaised
          : colors.surface,
      elevation: selected ? 0 : theme.geo.elevationLow,
      shadowColor: colors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: theme.geo.radiusLarge,
        side: selected ? BorderSide(color: colors.accent, width: 2) : BorderSide(color: colors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
