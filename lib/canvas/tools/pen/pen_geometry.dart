// Defines raw pen strokes, smoothed paths, hit padding, and canvas positioning.
// Used by pen sampling, persisted stroke models, rendering, and hit testing.

part of 'pen_tool.dart';

// ---------- Types and geometry ----------

/// Carries sampled screen-space points with their committed pen options.
/// Produced by [PenTool] and positioned by the canvas editor.
typedef RawPenStroke = ({
  List<PenPointData> points,
  int color,
  double width,
});

const _strokeHitSlop = 6.0;
const _minimumPointDistanceSquared = 4.0;

/// Builds the filled freehand outline for sampled pen points.
/// Used by live previews and persisted stroke rendering.
Path createPenPath(List<PenPointData> points, double width) {
  final simulatePressure = points.isNotEmpty && points.every((point) => point.pressure == points.first.pressure);
  final outline = pf.getStroke(
    [
      for (final point in points)
        pf.PointVector(
          point.position.dx,
          point.position.dy,
          point.pressure,
        ),
    ],
    options: pf.StrokeOptions(
      size: width * 2,
      simulatePressure: simulatePressure,
    ),
  );
  if (outline.isEmpty) return Path();
  if (outline.length == 1) {
    return Path()..addOval(Rect.fromCircle(center: outline.single, radius: 1));
  }
  final path = Path()..moveTo(outline.first.dx, outline.first.dy);
  for (var index = 1; index < outline.length - 1; index++) {
    final point = outline[index];
    final next = outline[index + 1];
    path.quadraticBezierTo(
      point.dx,
      point.dy,
      (point.dx + next.dx) / 2,
      (point.dy + next.dy) / 2,
    );
  }
  return path;
}

// ---------- Persistence geometry ----------

/// Converts a sampled screen-space stroke into persisted canvas coordinates.
/// Used when the canvas editor commits a completed [RawPenStroke].
PenElementData positionStroke(
  RawPenStroke stroke, {
  required String id,
  required Offset canvasOffset,
  required double canvasScale,
}) {
  final positions = stroke.points.map((point) => point.position);
  final minX = positions.map((point) => point.dx).reduce((a, b) => a < b ? a : b);
  final minY = positions.map((point) => point.dy).reduce((a, b) => a < b ? a : b);
  final maxX = positions.map((point) => point.dx).reduce((a, b) => a > b ? a : b);
  final maxY = positions.map((point) => point.dy).reduce((a, b) => a > b ? a : b);
  final padding = stroke.width + _strokeHitSlop;
  final screenOrigin = Offset(minX - padding, minY - padding);

  return PenElementData(
    id: id,
    position: screenOrigin / canvasScale + canvasOffset,
    hitSlop: _strokeHitSlop / canvasScale,
    size: Size(maxX - minX + padding * 2, maxY - minY + padding * 2) / canvasScale,
    points: [
      for (final point in stroke.points)
        PenPointData(
          (point.position - screenOrigin) / canvasScale,
          pressure: point.pressure,
        ),
    ],
    color: stroke.color,
    width: stroke.width / canvasScale,
  );
}
