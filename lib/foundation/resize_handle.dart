import 'package:beyond/foundation/control_surface.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';

class ResizeHandle extends StatelessWidget {
  const ResizeHandle({
    required this.semanticLabel,
    required this.gestures,
    this.background = true,
    super.key,
  });

  final String semanticLabel;
  final Map<Type, GestureRecognizerFactory> gestures;
  final bool background;

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox(
      width: 32,
      height: 20,
      child: Center(
        child: Icon(
          Icons.open_in_full,
          size: 16,
          color: BTheme.of(context).colors.textMuted,
        ),
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: gestures,
          child: background ? ControlSurface(child: icon) : icon,
        ),
      ),
    );
  }
}
