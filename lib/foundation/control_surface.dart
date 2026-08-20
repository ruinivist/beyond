import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';

class ControlSurface extends StatelessWidget {
  const ControlSurface({
    required this.child,
    this.selected = false,
    super.key,
  });

  final Widget child;
  final bool selected;

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
