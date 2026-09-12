// Provides Beyond's draggable icon control.
// Used by canvas controls that start pointer transformations.

import 'package:beyond/ui/common/b_container.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ---------- Widgets ----------

class IconDrag extends StatelessWidget {
  // ---------- Construction ----------

  const IconDrag({
    required this.icon,
    required this.semanticLabel,
    required this.onDragStart,
    super.key,
  });

  final Widget icon;
  final String semanticLabel;
  final GestureMultiDragStartCallback onDragStart;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    return BContainer(
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Semantics(
          button: true,
          label: semanticLabel,
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
    );
  }
}
