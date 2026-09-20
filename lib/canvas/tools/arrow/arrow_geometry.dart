// Defines arrow paths, bounds, hit padding, and default curvature.
// Used by arrow models, creation previews, rendering, and hit testing.

part of 'arrow_tool.dart';

// ---------- Geometry ----------

const _arrowHeadLength = 12.0;
const _arrowHeadHalfWidth = 5.0;
const _arrowHitSlop = 8.0;
const _arrowDashLength = 8.0;
const _arrowDashGap = 6.0;

/// Calculates the curve, arrowhead, and interaction bounds of an arrow.
/// Used by arrow models, painters, and previews.
class ArrowGeometry {
  const ArrowGeometry({
    required this.start,
    required this.control,
    required this.end,
  });

  final Offset start;
  final Offset control;
  final Offset end;

  Offset get endTangent {
    final tangent = end - control;
    if (tangent == Offset.zero) return const Offset(1, 0);
    return tangent / tangent.distance;
  }

  Offset get arrowheadBase => end - endTangent * _arrowHeadLength;

  Offset get arrowheadLeft {
    final tangent = endTangent;
    return arrowheadBase + Offset(-tangent.dy, tangent.dx) * _arrowHeadHalfWidth;
  }

  Offset get arrowheadRight {
    final tangent = endTangent;
    return arrowheadBase - Offset(-tangent.dy, tangent.dx) * _arrowHeadHalfWidth;
  }

  Path get shaftPath => Path()
    ..moveTo(start.dx, start.dy)
    ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

  Path get arrowheadPath {
    return Path()
      ..moveTo(arrowheadLeft.dx, arrowheadLeft.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(arrowheadRight.dx, arrowheadRight.dy);
  }

  Rect get bounds => shaftPath
      .getBounds()
      .expandToInclude(arrowheadPath.getBounds())
      .inflate(_arrowHitSlop + arrowStrokeWidthMaximum / 2);

  ArrowGeometry shift(Offset offset) => ArrowGeometry(
    start: start + offset,
    control: control + offset,
    end: end + offset,
  );
}

void paintArrow(
  Canvas canvas, {
  required ArrowGeometry geometry,
  required Color color,
  required ArrowStrokeStyle strokeStyle,
  required double strokeWidth,
  double dashScale = 1,
}) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = strokeWidth;
  canvas
    ..drawPath(
      strokeStyle == ArrowStrokeStyle.dashed
          ? _dashedPath(
              geometry.shaftPath,
              dashLength: _arrowDashLength * dashScale,
              gapLength: _arrowDashGap * dashScale,
            )
          : geometry.shaftPath,
      paint,
    )
    ..drawPath(geometry.arrowheadPath, paint);
}

Path _dashedPath(
  Path source, {
  required double dashLength,
  required double gapLength,
}) {
  final result = Path();
  for (final metric in source.computeMetrics()) {
    for (var distance = 0.0; distance < metric.length; distance += dashLength + gapLength) {
      result.addPath(
        metric.extractPath(distance, math.min(distance + dashLength, metric.length)),
        Offset.zero,
      );
    }
  }
  return result;
}

// ---------- Control geometry ----------

/// Places the control point that gives a new arrow its default bend.
/// Used while previewing and committing arrows from pointer drags.
Offset arrowControlPoint({
  required Offset start,
  required Offset end,
}) {
  final vector = end - start;
  final length = vector.distance;
  if (length == 0) return start;

  final bendLength = (length * 0.09).clamp(6.0, 32.0);
  final normal = Offset(vector.dy / length, -vector.dx / length);

  return start + vector * 0.5 + normal * bendLength;
}
