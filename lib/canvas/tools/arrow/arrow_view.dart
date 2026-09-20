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

/// Draws and handles the three editable points of an active arrow.
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
  final void Function(ArrowPoint point, Offset position) onPointChanged;
  final VoidCallback onChangeEnd;

  Offset _toScreen(Offset point) => (point - canvasOffset) * canvasScale;

  @override
  Widget build(BuildContext context) {
    final colors = BTheme.of(context).colors;
    final points = {
      for (final point in ArrowPoint.values) point: _toScreen(model.point(point)),
    };
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: const ValueKey('arrow-bezier-guides'),
              painter: _ArrowGuidePainter(
                start: points[ArrowPoint.start]!,
                control: points[ArrowPoint.control]!,
                end: points[ArrowPoint.end]!,
                color: colors.accent.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
        for (final point in ArrowPoint.values)
          Positioned(
            left: points[point]!.dx - _ArrowPointHandle.size / 2,
            top: points[point]!.dy - _ArrowPointHandle.size / 2,
            child: _ArrowPointHandle(
              key: ValueKey('arrow-${point.name}-handle'),
              point: point,
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
    required this.point,
    required this.position,
    required this.canvasScale,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  static const size = 28.0;
  static const visualSize = 10.0;

  final ArrowPoint point;
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
        label: 'Move arrow ${widget.point.name} point',
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
                  color: widget.point == ArrowPoint.control ? colors.accent : colors.surface,
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
    required this.start,
    required this.control,
    required this.end,
    required this.color,
  });

  final Offset start;
  final Offset control;
  final Offset end;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas
      ..drawLine(start, control, paint)
      ..drawLine(control, end, paint);
  }

  @override
  bool shouldRepaint(_ArrowGuidePainter oldDelegate) =>
      start != oldDelegate.start ||
      control != oldDelegate.control ||
      end != oldDelegate.end ||
      color != oldDelegate.color;
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
        oldDelegate.color != color ||
        oldDelegate.strokeStyle != strokeStyle ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
