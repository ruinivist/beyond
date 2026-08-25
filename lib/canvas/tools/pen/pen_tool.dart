import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_element_model.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';

typedef PositionedSketch = ({
  Offset position,
  Size size,
  Sketch sketch,
  double hitSlop,
});

const _strokeHitSlop = 6.0;

class PenStrokeModel extends CanvasElementModel<PenElementData> {
  PenStrokeModel(super.data);

  Sketch get sketch => data.sketch;

  double get hitSlop => data.hitSlop;

  @override
  Offset get canvasPosition => data.position;

  @override
  Size get canvasSize => data.size;

  @override
  void moveBy(Offset delta) {
    if (delta == Offset.zero) return;
    data.position += delta;
    notifyListeners();
  }
}

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
                foregroundPainter: _PenStrokePainter(
                  sketch: model.sketch,
                  hitSlop: model.hitSlop,
                  selected: model.selected,
                  accent: accent,
                ),
                child: IgnorePointer(
                  child: ScribbleSketch(sketch: model.sketch),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PenStrokePainter extends CustomPainter {
  const _PenStrokePainter({
    required this.sketch,
    required this.hitSlop,
    required this.selected,
    required this.accent,
  });

  final Sketch sketch;
  final double hitSlop;
  final bool selected;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (!selected) return;
    canvas.drawRect(
      (Offset.zero & size).deflate(1),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool hitTest(Offset position) {
    for (final line in sketch.lines) {
      final points = line.points;
      if (points.isEmpty) continue;
      final radius = line.width + hitSlop;
      final radiusSquared = radius * radius;
      if (points.length == 1) {
        final delta = position - Offset(points.first.x, points.first.y);
        if (delta.distanceSquared <= radiusSquared) return true;
        continue;
      }
      for (var index = 1; index < points.length; index++) {
        final start = Offset(points[index - 1].x, points[index - 1].y);
        final end = Offset(points[index].x, points[index].y);
        if (_distanceToSegmentSquared(position, start, end) <= radiusSquared) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  bool shouldRepaint(_PenStrokePainter oldDelegate) {
    return oldDelegate.sketch != sketch ||
        oldDelegate.selected != selected ||
        oldDelegate.accent != accent;
  }
}

double _distanceToSegmentSquared(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.distanceSquared;
  if (lengthSquared == 0) return (point - start).distanceSquared;
  final offset = point - start;
  final ratio =
      ((offset.dx * segment.dx + offset.dy * segment.dy) / lengthSquared).clamp(
        0.0,
        1.0,
      );
  return (point - (start + segment * ratio)).distanceSquared;
}

class PenTool extends ScribbleNotifier {
  PenTool({required this.onStroke});

  final ValueChanged<Sketch> onStroke;
  final _activePointerIds = <int>{};
  Color? _pendingColor;
  double? _pendingStrokeWidth;

  bool _isAllowedPointer(PointerEvent event) =>
      event.kind != PointerDeviceKind.mouse || event.buttons == kPrimaryButton;

  @override
  void setColor(Color color) {
    if (value.activePointerIds.isNotEmpty) {
      _pendingColor = color;
      return;
    }
    super.setColor(color);
  }

  @override
  void setStrokeWidth(double strokeWidth) {
    if (value.activePointerIds.isNotEmpty) {
      _pendingStrokeWidth = strokeWidth;
      return;
    }
    super.setStrokeWidth(strokeWidth);
  }

  void _commit() {
    final sketch = currentSketch;
    if (sketch.lines.isEmpty) return;
    onStroke(sketch);
    clear();
  }

  void _applyPendingSettings() {
    if (value.activePointerIds.isNotEmpty) return;
    final color = _pendingColor;
    final strokeWidth = _pendingStrokeWidth;
    _pendingColor = null;
    _pendingStrokeWidth = null;
    if (color != null) super.setColor(color);
    if (strokeWidth != null) super.setStrokeWidth(strokeWidth);
  }

  @override
  void onPointerUp(PointerUpEvent event) {
    if (!_activePointerIds.remove(event.pointer)) return;
    super.onPointerUp(event);
    _commit();
    _applyPendingSettings();
  }

  @override
  void onPointerCancel(PointerCancelEvent event) {
    if (!_activePointerIds.remove(event.pointer)) return;
    super.onPointerCancel(event);
    _commit();
    _applyPendingSettings();
  }

  @override
  void onPointerExit(PointerExitEvent event) {
    if (!_activePointerIds.remove(event.pointer)) return;
    super.onPointerExit(event);
    _commit();
    _applyPendingSettings();
  }

  @override
  void onPointerDown(PointerDownEvent event) {
    if (!_isAllowedPointer(event)) return;
    _activePointerIds.add(event.pointer);
    super.onPointerDown(event);
  }

  @override
  void onPointerUpdate(PointerMoveEvent event) {
    if (!_activePointerIds.contains(event.pointer)) return;
    super.onPointerUpdate(event);
  }
}

PositionedSketch positionSketch(
  Sketch sketch, {
  required Offset canvasOffset,
  required double canvasScale,
}) {
  final points = sketch.lines.expand((line) => line.points);
  final minX = points.map((point) => point.x).reduce((a, b) => a < b ? a : b);
  final minY = points.map((point) => point.y).reduce((a, b) => a < b ? a : b);
  final maxX = points.map((point) => point.x).reduce((a, b) => a > b ? a : b);
  final maxY = points.map((point) => point.y).reduce((a, b) => a > b ? a : b);
  final padding =
      sketch.lines.map((line) => line.width).reduce((a, b) => a > b ? a : b) +
      _strokeHitSlop;
  final screenOrigin = Offset(minX - padding, minY - padding);
  final position = screenOrigin / canvasScale + canvasOffset;

  return (
    position: position,
    hitSlop: _strokeHitSlop / canvasScale,
    size:
        Size(maxX - minX + padding * 2, maxY - minY + padding * 2) /
        canvasScale,
    sketch: Sketch(
      lines: [
        for (final line in sketch.lines)
          line.copyWith(
            width: line.width / canvasScale,
            points: [
              for (final point in line.points)
                point.copyWith(
                  x: (point.x - screenOrigin.dx) / canvasScale,
                  y: (point.y - screenOrigin.dy) / canvasScale,
                ),
            ],
          ),
      ],
    ),
  );
}
