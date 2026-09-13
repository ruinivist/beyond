// Renders persisted arrows and performs path-level hit testing.
// Used by the canvas element stack for saved arrow models.

part of 'arrow_tool.dart';

// ---------- Rendering ----------

/// Renders and exposes semantics for a persisted arrow model.
/// Used by the canvas element stack.
class Arrow extends StatelessWidget {
  const Arrow({required this.model, super.key});

  final ArrowModel model;

  @override
  Widget build(BuildContext context) {
    final colors = BTheme.of(context).colors;
    return SizedBox.fromSize(
      size: model.canvasSize,
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) {
          return Semantics(
            container: true,
            label: 'Arrow',
            selected: model.selected,
            child: CustomPaint(
              foregroundPainter: _ArrowPainter(
                geometry: model.localGeometry,
                color: model.selected ? colors.accent : colors.textSecondary,
              ),
              child: const IgnorePointer(child: SizedBox.expand()),
            ),
          );
        },
      ),
    );
  }
}

// ---------- Painter ----------

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.geometry, required this.color});

  final ArrowGeometry geometry;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    paintArrow(
      canvas,
      geometry: geometry,
      color: color,
      strokeWidth: _arrowStrokeWidth,
    );
  }

  @override
  bool hitTest(Offset position) {
    const radius = _arrowStrokeWidth / 2 + _arrowHitSlop;
    const radiusSquared = radius * radius;
    Offset curvePoint(double t) {
      final oneMinusT = 1 - t;
      return geometry.start * (oneMinusT * oneMinusT) + geometry.control * (2 * oneMinusT * t) + geometry.end * (t * t);
    }

    var previous = geometry.start;
    for (var index = 1; index <= 24; index++) {
      final current = curvePoint(index / 24);
      if (distanceToSegmentSquared(position, previous, current) <= radiusSquared) {
        return true;
      }
      previous = current;
    }
    return distanceToSegmentSquared(
              position,
              geometry.arrowheadLeft,
              geometry.end,
            ) <=
            radiusSquared ||
        distanceToSegmentSquared(
              position,
              geometry.end,
              geometry.arrowheadRight,
            ) <=
            radiusSquared;
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) {
    return oldDelegate.geometry.start != geometry.start ||
        oldDelegate.geometry.control != geometry.control ||
        oldDelegate.geometry.end != geometry.end ||
        oldDelegate.color != color;
  }
}
