// Renders persisted pen strokes and performs stroke-level hit testing.
// Used by the canvas element stack for saved freehand drawings.

part of 'pen_tool.dart';

// ---------- Rendering ----------

/// Renders and handles movement for a persisted freehand stroke.
/// Used by the canvas element stack.
class PenStroke extends StatelessWidget {
  const PenStroke({
    required this.model,
    required this.onPointerDown,
    required this.onMove,
    super.key,
  });

  final PenStrokeModel model;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    final accent = BTheme.of(context).colors.accent;
    return SizedBox.fromSize(
      size: model.canvasSize,
      child: Listener(
        onPointerDown: onPointerDown,
        child: ListenableBuilder(
          listenable: model,
          builder: (context, _) => Semantics(
            container: true,
            label: 'Drawing stroke',
            selected: model.selected,
            child: GestureDetector(
              onPanUpdate: (details) => onMove(details.delta),
              child: CustomPaint(
                painter: _PenStrokePainter(
                  path: model.path,
                  points: model.data.points,
                  color: Color(model.data.color),
                  width: model.data.width,
                  hitSlop: model.data.hitSlop,
                  selected: model.selected,
                  accent: accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Painter and hit testing ----------

class _PenStrokePainter extends CustomPainter {
  const _PenStrokePainter({
    required this.path,
    required this.points,
    required this.color,
    required this.width,
    required this.hitSlop,
    required this.selected,
    required this.accent,
  });

  final Path path;
  final List<PenPointData> points;
  final Color color;
  final double width;
  final double hitSlop;
  final bool selected;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    if (selected) {
      canvas.drawRect(
        (Offset.zero & size).deflate(1),
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool hitTest(Offset position) {
    final radiusSquared = (width + hitSlop) * (width + hitSlop);
    if (points.length == 1) {
      return (position - points.single.position).distanceSquared <= radiusSquared;
    }
    for (var index = 1; index < points.length; index++) {
      if (_distanceToSegmentSquared(
            position,
            points[index - 1].position,
            points[index].position,
          ) <=
          radiusSquared) {
        return true;
      }
    }
    return false;
  }

  @override
  bool shouldRepaint(_PenStrokePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.selected != selected ||
      oldDelegate.accent != accent;
}

double _distanceToSegmentSquared(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.distanceSquared;
  if (lengthSquared == 0) return (point - start).distanceSquared;
  final offset = point - start;
  final ratio = ((offset.dx * segment.dx + offset.dy * segment.dy) / lengthSquared).clamp(
    0.0,
    1.0,
  );
  return (point - (start + segment * ratio)).distanceSquared;
}
