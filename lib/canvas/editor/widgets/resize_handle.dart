// Provides the themed drag handle shown on resizable canvas elements.
// Used by text, code, media, and shape element controls.

import 'package:beyond/ui/common/resize_icon.dart';
import 'package:flutter/material.dart';

// ---------- Widgets ----------

class ResizeHandle extends StatelessWidget {
  // ---------- Construction ----------

  const ResizeHandle({
    required this.semanticLabel,
    required this.gestures,
    super.key,
  });

  final String semanticLabel;
  final Map<Type, GestureRecognizerFactory> gestures;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: gestures,
          child: const ResizeIcon(),
        ),
      ),
    );
  }
}
