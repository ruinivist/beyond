// Renders persisted shapes with movement, resizing, and hit testing.
// Used by the canvas element stack for saved shape models.

part of 'shape_tool.dart';

// ---------- Rendering ----------

/// Renders and handles movement and resizing for a persisted shape.
/// Used by the canvas element stack.
class Shape extends StatelessWidget {
  const Shape({
    required this.model,
    required this.onActivate,
    required this.onMove,
    required this.onResize,
    super.key,
  });

  final ShapeModel model;
  final VoidCallback onActivate;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;

  @override
  Widget build(BuildContext context) {
    final colors = BTheme.of(context).colors;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => SizedBox.fromSize(
        size: model.canvasSize,
        child: Semantics(
          container: true,
          label: model.data.kind.label,
          selected: model.selected,
          child: GestureDetector(
            dragStartBehavior: DragStartBehavior.down,
            onTap: onActivate,
            onPanUpdate: (details) => onMove(details.delta),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ShapePainter(
                      path: shapePath(
                        model.data.kind,
                        Offset.zero & model.canvasSize,
                      ),
                      color: model.selected ? colors.accent : Color(model.data.strokeColor),
                      fillColor: model.data.fillColor == null ? null : Color(model.data.fillColor!),
                      strokeWidth: model.data.strokeWidth,
                    ),
                  ),
                ),
                if (model.active)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: ResizeHandle(
                      key: const ValueKey('shape-resize-handle'),
                      semanticLabel: 'Resize shape',
                      gestures: {
                        ImmediateMultiDragGestureRecognizer: immediateDragGestureFactory((_) => CallbackDrag(onResize)),
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Painter ----------

class _ShapePainter extends CustomPainter {
  const _ShapePainter({
    required this.path,
    required this.color,
    required this.fillColor,
    required this.strokeWidth,
  });

  final Path path;
  final Color color;
  final Color? fillColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    paintShape(
      canvas,
      path: path,
      color: color,
      fillColor: fillColor,
      strokeWidth: strokeWidth,
    );
  }

  @override
  bool hitTest(Offset position) => path.contains(position);

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
