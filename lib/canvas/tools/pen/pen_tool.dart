import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';

typedef PositionedSketch = ({Offset position, Size size, Sketch sketch});

class PenTool extends ScribbleNotifier {
  PenTool({required this.onStroke});

  final ValueChanged<Sketch> onStroke;

  void _commit() {
    final sketch = currentSketch;
    if (sketch.lines.isEmpty) return;
    onStroke(sketch);
    clear();
  }

  @override
  void onPointerUp(PointerUpEvent event) {
    super.onPointerUp(event);
    _commit();
  }

  @override
  void onPointerCancel(PointerCancelEvent event) {
    super.onPointerCancel(event);
    _commit();
  }

  @override
  void onPointerExit(PointerExitEvent event) {
    super.onPointerExit(event);
    _commit();
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
  final padding = sketch.lines
      .map((line) => line.width)
      .reduce((a, b) => a > b ? a : b);
  final screenOrigin = Offset(minX - padding, minY - padding);
  final position = screenOrigin / canvasScale + canvasOffset;

  return (
    position: position,
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
