import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_element_model.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart' as pf;

typedef RawPenStroke = ({
  List<PenPointData> points,
  int color,
  double width,
});

const _strokeHitSlop = 6.0;
const _minimumPointDistanceSquared = 4.0;

Path createPenPath(List<PenPointData> points, double width) {
  final simulatePressure =
      points.isNotEmpty &&
      points.every((point) => point.pressure == points.first.pressure);
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

class PenStrokeModel extends CanvasElementModel<PenElementData> {
  PenStrokeModel(super.data) : path = createPenPath(data.points, data.width);

  final Path path;

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
      return (position - points.single.position).distanceSquared <=
          radiusSquared;
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
  final ratio =
      ((offset.dx * segment.dx + offset.dy * segment.dy) / lengthSquared).clamp(
        0.0,
        1.0,
      );
  return (point - (start + segment * ratio)).distanceSquared;
}

class PenTool extends ChangeNotifier {
  PenTool({required this.onStroke});

  final ValueChanged<RawPenStroke> onStroke;
  final _points = <PenPointData>[];
  int? _activePointer;
  Offset? _pointerPosition;
  Color _color = Colors.black;
  double _strokeWidth = 4;
  Color? _pendingColor;
  double? _pendingStrokeWidth;

  bool get active => _activePointer != null;

  void setColor(Color color) {
    if (active) {
      _pendingColor = color;
    } else {
      _color = color;
      notifyListeners();
    }
  }

  void setStrokeWidth(double strokeWidth) {
    if (active) {
      _pendingStrokeWidth = strokeWidth;
    } else {
      _strokeWidth = strokeWidth;
      notifyListeners();
    }
  }

  bool _isAllowedPointer(PointerDownEvent event) => switch (event.kind) {
    PointerDeviceKind.mouse => event.buttons & kPrimaryButton != 0,
    PointerDeviceKind.touch ||
    PointerDeviceKind.stylus ||
    PointerDeviceKind.invertedStylus => true,
    _ => false,
  };

  double _pressure(PointerEvent event) {
    if (event.pressureMin == event.pressureMax) return 0.5;
    return ((event.pressure - event.pressureMin) /
            (event.pressureMax - event.pressureMin))
        .clamp(0.0, 1.0);
  }

  void _append(PointerEvent event) {
    final position = event.localPosition;
    if (_points.isNotEmpty &&
        (position - _points.last.position).distanceSquared <=
            _minimumPointDistanceSquared) {
      return;
    }
    _points.add(PenPointData(position, pressure: _pressure(event)));
  }

  void onPointerDown(PointerDownEvent event) {
    if (active || !_isAllowedPointer(event)) return;
    _activePointer = event.pointer;
    _pointerPosition = event.localPosition;
    _append(event);
    notifyListeners();
  }

  void onPointerUpdate(PointerMoveEvent event) {
    if (active && event.pointer != _activePointer) return;
    _pointerPosition = event.localPosition;
    if (!active) {
      notifyListeners();
      return;
    }
    _append(event);
    notifyListeners();
  }

  void onPointerHover(PointerHoverEvent event) {
    if (active && event.pointer != _activePointer) return;
    _pointerPosition = event.localPosition;
    notifyListeners();
  }

  void onPointerUp(PointerUpEvent event) => _finish(event);

  void onPointerCancel(PointerCancelEvent event) => _finish(event);

  void onPointerExit(PointerExitEvent event) {
    if (!active) {
      _pointerPosition = null;
      notifyListeners();
      return;
    }
    _finish(event);
  }

  void _finish(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _pointerPosition = event is PointerExitEvent ? null : event.localPosition;
    _append(event);
    final stroke = (
      points: List<PenPointData>.of(_points),
      color: _color.toARGB32(),
      width: _strokeWidth,
    );
    _activePointer = null;
    _points.clear();
    final pendingColor = _pendingColor;
    final pendingWidth = _pendingStrokeWidth;
    _pendingColor = null;
    _pendingStrokeWidth = null;
    onStroke(stroke);
    if (pendingColor != null) _color = pendingColor;
    if (pendingWidth != null) _strokeWidth = pendingWidth;
    notifyListeners();
  }
}

class PenPreviewPainter extends CustomPainter {
  PenPreviewPainter({required this.tool, required this.color})
    : super(repaint: tool);

  final PenTool tool;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      createPenPath(tool._points, tool._strokeWidth),
      Paint()
        ..color = tool._color
        ..style = PaintingStyle.fill,
    );
    if (tool._pointerPosition case final pointer?) {
      canvas.drawCircle(
        pointer,
        tool._strokeWidth / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(PenPreviewPainter oldDelegate) => false;
}

PenElementData positionStroke(
  RawPenStroke stroke, {
  required String id,
  required Offset canvasOffset,
  required double canvasScale,
}) {
  final positions = stroke.points.map((point) => point.position);
  final minX = positions
      .map((point) => point.dx)
      .reduce((a, b) => a < b ? a : b);
  final minY = positions
      .map((point) => point.dy)
      .reduce((a, b) => a < b ? a : b);
  final maxX = positions
      .map((point) => point.dx)
      .reduce((a, b) => a > b ? a : b);
  final maxY = positions
      .map((point) => point.dy)
      .reduce((a, b) => a > b ? a : b);
  final padding = stroke.width + _strokeHitSlop;
  final screenOrigin = Offset(minX - padding, minY - padding);

  return PenElementData(
    id: id,
    position: screenOrigin / canvasScale + canvasOffset,
    hitSlop: _strokeHitSlop / canvasScale,
    size:
        Size(maxX - minX + padding * 2, maxY - minY + padding * 2) /
        canvasScale,
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
