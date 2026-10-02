// Renders persisted arrows, active editing points, and path-level hit testing.
// Used by the canvas element stack and active arrow editing overlay.

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
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => SizedBox.fromSize(
        size: model.canvasSize,
        child: Semantics(
          container: true,
          label: 'Arrow',
          selected: model.selected,
          child: CustomPaint(
            foregroundPainter: _ArrowPainter(
              geometry: model.localGeometry,
              color: model.selected && !model.active ? colors.accent : model.color,
              strokeStyle: model.strokeStyle,
              strokeWidth: model.strokeWidth,
            ),
            child: const IgnorePointer(child: SizedBox.expand()),
          ),
        ),
      ),
    );
  }
}

/// Draws and handles every editable point of an active arrow.
class ArrowEditor extends StatelessWidget {
  const ArrowEditor({
    required this.model,
    required this.canvasOffset,
    required this.canvasScale,
    required this.onChangeStart,
    required this.onPointChanged,
    required this.onChangeEnd,
    super.key,
  });

  final ArrowModel model;
  final Offset canvasOffset;
  final double canvasScale;
  final VoidCallback onChangeStart;
  final void Function(int point, Offset position) onPointChanged;
  final VoidCallback onChangeEnd;

  Offset _toScreen(Offset point) => (point - canvasOffset) * canvasScale;

  @override
  Widget build(BuildContext context) {
    final colors = BTheme.of(context).colors;
    final points = [for (var point = 0; point < model.pointCount; point++) _toScreen(model.point(point))];
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: const ValueKey('arrow-bezier-guides'),
              painter: _ArrowGuidePainter(
                points: points,
                color: colors.accent.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
        for (var point = 0; point < points.length; point++)
          Positioned(
            left: points[point].dx - _ArrowPointHandle.size / 2,
            top: points[point].dy - _ArrowPointHandle.size / 2,
            child: _ArrowPointHandle(
              key: ValueKey(
                'arrow-${point == 0
                    ? 'start'
                    : point == points.length - 1
                    ? 'end'
                    : 'control-${point - 1}'}-handle',
              ),
              label: point == 0
                  ? 'start'
                  : point == points.length - 1
                  ? 'end'
                  : 'control $point',
              isControl: point > 0 && point < points.length - 1,
              position: model.point(point),
              canvasScale: canvasScale,
              onChangeStart: onChangeStart,
              onChanged: (position) => onPointChanged(point, position),
              onChangeEnd: onChangeEnd,
            ),
          ),
      ],
    );
  }
}

class _ArrowPointHandle extends StatefulWidget {
  const _ArrowPointHandle({
    required this.label,
    required this.isControl,
    required this.position,
    required this.canvasScale,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  static const size = 28.0;
  static const visualSize = 10.0;

  final String label;
  final bool isControl;
  final Offset position;
  final double canvasScale;
  final VoidCallback onChangeStart;
  final ValueChanged<Offset> onChanged;
  final VoidCallback onChangeEnd;

  @override
  State<_ArrowPointHandle> createState() => _ArrowPointHandleState();
}

class _ArrowPointHandleState extends State<_ArrowPointHandle> {
  Offset? _requestedPosition;

  @override
  Widget build(BuildContext context) {
    final colors = BTheme.of(context).colors;
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: Semantics(
        button: true,
        label: 'Move arrow ${widget.label} point',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (_) {
            _requestedPosition = widget.position;
            widget.onChangeStart();
          },
          onPanUpdate: (details) {
            final position = _requestedPosition! + details.delta / widget.canvasScale;
            _requestedPosition = position;
            widget.onChanged(position);
          },
          onPanEnd: (_) => _finishDrag(),
          onPanCancel: _finishDrag,
          child: SizedBox.square(
            dimension: _ArrowPointHandle.size,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.isControl ? colors.accent : colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.accent, width: 2),
                ),
                child: const SizedBox.square(dimension: _ArrowPointHandle.visualSize),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _finishDrag() {
    _requestedPosition = null;
    widget.onChangeEnd();
  }
}

class _ArrowGuidePainter extends CustomPainter {
  const _ArrowGuidePainter({
    required this.points,
    required this.color,
  });

  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var index = 1; index < points.length; index++) {
      canvas.drawLine(points[index - 1], points[index], paint);
    }
  }

  @override
  bool shouldRepaint(_ArrowGuidePainter oldDelegate) =>
      !listEquals(points, oldDelegate.points) || color != oldDelegate.color;
}

// ---------- Painter ----------

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({
    required this.geometry,
    required this.color,
    required this.strokeStyle,
    required this.strokeWidth,
  });

  final ArrowGeometry geometry;
  final Color color;
  final ArrowStrokeStyle strokeStyle;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    paintArrow(
      canvas,
      geometry: geometry,
      color: color,
      strokeStyle: strokeStyle,
      strokeWidth: strokeWidth,
    );
  }

  @override
  bool hitTest(Offset position) {
    final radius = strokeWidth / 2 + _arrowHitSlop;
    final radiusSquared = radius * radius;
    for (final metric in geometry.shaftPath.computeMetrics()) {
      var previous = geometry.start;
      final steps = (metric.length / (radius / 2)).ceil();
      for (var index = 1; index <= steps; index++) {
        final current = metric.getTangentForOffset(metric.length * index / steps)!.position;
        if (distanceToSegmentSquared(position, previous, current) <= radiusSquared) {
          return true;
        }
        previous = current;
      }
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
        !listEquals(oldDelegate.geometry.controls, geometry.controls) ||
        oldDelegate.geometry.end != geometry.end ||
        oldDelegate.color != color ||
        oldDelegate.strokeStyle != strokeStyle ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
