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
  ArrowGeometry({
    required this.start,
    required List<Offset> controls,
    required this.end,
  }) : assert(controls.isNotEmpty, 'An arrow needs at least one control'),
       controls = List.unmodifiable(controls);

  final Offset start;
  final List<Offset> controls;
  final Offset end;

  Offset get endTangent {
    for (final point in [...controls.reversed, start]) {
      final tangent = end - point;
      if (tangent != Offset.zero) return tangent / tangent.distance;
    }
    return const Offset(1, 0);
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

  Path get shaftPath {
    final path = Path()..moveTo(start.dx, start.dy);
    for (var index = 0; index < controls.length; index++) {
      final control = controls[index];
      final join = index == controls.length - 1 ? end : (control + controls[index + 1]) / 2;
      path.quadraticBezierTo(control.dx, control.dy, join.dx, join.dy);
    }
    return path;
  }

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
    controls: [for (final control in controls) control + offset],
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
