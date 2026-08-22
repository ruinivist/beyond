import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const arrowMinimumLength = 4.0;
const _arrowStrokeWidth = 2.0;
const _arrowHeadLength = 12.0;
const _arrowHeadHalfWidth = 5.0;
const _arrowHitSlop = 8.0;

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
    return arrowheadBase +
        Offset(-tangent.dy, tangent.dx) * _arrowHeadHalfWidth;
  }

  Offset get arrowheadRight {
    final tangent = endTangent;
    return arrowheadBase -
        Offset(-tangent.dy, tangent.dx) * _arrowHeadHalfWidth;
  }

  Path get path {
    return Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy)
      ..moveTo(arrowheadLeft.dx, arrowheadLeft.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(arrowheadRight.dx, arrowheadRight.dy);
  }

  Rect get bounds => path.getBounds().inflate(
    _arrowHitSlop + _arrowStrokeWidth / 2,
  );

  ArrowGeometry shift(Offset offset) => ArrowGeometry(
    start: start + offset,
    control: control + offset,
    end: end + offset,
  );
}

class ArrowModel extends ChangeNotifier {
  ArrowModel({required this.id, required Offset start, required Offset end})
    : _geometry = ArrowGeometry(
        start: start,
        control: arrowControlPoint(id: id, start: start, end: end),
        end: end,
      ),
      _initialBounds = ArrowGeometry(
        start: start,
        control: arrowControlPoint(id: id, start: start, end: end),
        end: end,
      ).bounds;

  final String id;
  final ArrowGeometry _geometry;
  final Rect _initialBounds;
  Offset _translation = Offset.zero;
  bool _selected = false;

  ArrowGeometry get geometry => _geometry.shift(_translation);

  ArrowGeometry get localGeometry => _geometry;

  Rect get bounds => _initialBounds.shift(_translation);

  Offset get start => geometry.start;

  Offset get control => geometry.control;

  Offset get end => geometry.end;

  bool get selected => _selected;

  set selected(bool value) {
    if (_selected == value) return;
    _selected = value;
    notifyListeners();
  }

  void moveBy(Offset delta) {
    if (delta == Offset.zero) return;
    _translation += delta;
    notifyListeners();
  }
}

class ArrowPreview {
  const ArrowPreview({required this.id, required this.geometry});

  final String id;
  final ArrowGeometry geometry;
}

class ArrowTool extends ChangeNotifier {
  ArrowTool({required this.onArrow});

  final ValueChanged<ArrowModel> onArrow;
  final _uuid = const Uuid();
  int? _pointer;
  String? _id;
  Offset? _start;
  Offset? _end;

  bool get isDrawing => _pointer != null;

  ArrowPreview? get preview {
    final id = _id;
    final start = _start;
    final end = _end;
    if (id == null || start == null || end == null) return null;
    return ArrowPreview(
      id: id,
      geometry: ArrowGeometry(
        start: start,
        control: arrowControlPoint(id: id, start: start, end: end),
        end: end,
      ),
    );
  }

  bool ownsPointer(int pointer) => _pointer == pointer;

  void onPointerDown(PointerDownEvent event, Offset canvasPosition) {
    if (event.buttons != kPrimaryButton || isDrawing) return;
    _pointer = event.pointer;
    _id = _uuid.v4();
    _start = canvasPosition;
    _end = canvasPosition;
    notifyListeners();
  }

  void onPointerMove(PointerMoveEvent event, Offset canvasPosition) {
    if (!ownsPointer(event.pointer)) return;
    _end = canvasPosition;
    notifyListeners();
  }

  void onPointerUp(PointerUpEvent event, Offset canvasPosition) {
    if (!ownsPointer(event.pointer)) return;
    _end = canvasPosition;
    final id = _id;
    final start = _start;
    final end = _end;
    final arrow = id != null && start != null && end != null
        ? _newArrow(id, start, end)
        : null;
    _clearPreview();
    if (arrow != null) onArrow(arrow);
  }

  void onPointerCancel(PointerCancelEvent event) {
    if (!ownsPointer(event.pointer)) return;
    _clearPreview();
  }

  ArrowModel? _newArrow(String id, Offset start, Offset end) {
    if ((end - start).distance < arrowMinimumLength) return null;
    return ArrowModel(id: id, start: start, end: end);
  }

  void _clearPreview() {
    _pointer = null;
    _id = null;
    _start = null;
    _end = null;
    notifyListeners();
  }
}

Offset arrowControlPoint({
  required String id,
  required Offset start,
  required Offset end,
}) {
  final vector = end - start;
  final length = vector.distance;
  if (length == 0) return start;

  final hash = _arrowHash(id, start, end);
  final controlT = hash.isEven ? -0.06 : 0.06;
  final side = hash & 2 == 0 ? -1.0 : 1.0;
  final variation = 0.85 + (hash % 31) / 100;
  final bow = length * 0.045;
  final bowLength = bow.clamp(3.0, 16.0) * 2 * variation;
  final normal = Offset(-vector.dy / length, vector.dx / length);

  return start + vector * (0.5 + controlT) + normal * side * bowLength;
}

class Arrow extends StatelessWidget {
  const Arrow({required this.model, required this.bounds, super.key});

  final ArrowModel model;
  final Rect bounds;

  @override
  Widget build(BuildContext context) {
    final colors = BTheme.of(context).colors;
    return SizedBox.fromSize(
      size: bounds.size,
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) {
          final geometry = model.localGeometry.shift(
            Offset(-bounds.left, -bounds.top),
          );
          return Semantics(
            container: true,
            label: 'Arrow',
            selected: model.selected,
            child: CustomPaint(
              foregroundPainter: _ArrowPainter(
                geometry: geometry,
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

class ArrowPreviewPainter extends CustomPainter {
  const ArrowPreviewPainter({
    required this.geometry,
    required this.canvasOffset,
    required this.canvasScale,
    required this.color,
  });

  final ArrowGeometry geometry;
  final Offset canvasOffset;
  final double canvasScale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final screenGeometry = ArrowGeometry(
      start: _toScreen(geometry.start),
      control: _toScreen(geometry.control),
      end: _toScreen(geometry.end),
    );
    canvas.drawPath(
      screenGeometry.path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = _arrowStrokeWidth * canvasScale,
    );
  }

  Offset _toScreen(Offset point) => (point - canvasOffset) * canvasScale;

  @override
  bool shouldRepaint(ArrowPreviewPainter oldDelegate) {
    return oldDelegate.geometry.start != geometry.start ||
        oldDelegate.geometry.control != geometry.control ||
        oldDelegate.geometry.end != geometry.end ||
        oldDelegate.canvasOffset != canvasOffset ||
        oldDelegate.canvasScale != canvasScale ||
        oldDelegate.color != color;
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.geometry, required this.color});

  final ArrowGeometry geometry;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      geometry.path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = _arrowStrokeWidth,
    );
  }

  @override
  bool hitTest(Offset position) {
    const radius = _arrowStrokeWidth / 2 + _arrowHitSlop;
    const radiusSquared = radius * radius;
    Offset curvePoint(double t) {
      final oneMinusT = 1 - t;
      return geometry.start * (oneMinusT * oneMinusT) +
          geometry.control * (2 * oneMinusT * t) +
          geometry.end * (t * t);
    }

    var previous = geometry.start;
    for (var index = 1; index <= 24; index++) {
      final current = curvePoint(index / 24);
      if (_distanceToSegmentSquared(position, previous, current) <=
          radiusSquared) {
        return true;
      }
      previous = current;
    }
    return _distanceToSegmentSquared(
              position,
              geometry.arrowheadLeft,
              geometry.end,
            ) <=
            radiusSquared ||
        _distanceToSegmentSquared(
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

int _arrowHash(String id, Offset start, Offset end) {
  var hash = 0x811c9dc5;

  void addByte(int byte) {
    hash ^= byte & 0xff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }

  for (final codeUnit in id.codeUnits) {
    addByte(codeUnit);
    addByte(codeUnit >> 8);
  }
  for (final coordinate in [start.dx, start.dy, end.dx, end.dy]) {
    var value = (coordinate * 1000).round();
    for (var index = 0; index < 4; index++) {
      addByte(value);
      value >>= 8;
    }
  }
  return hash;
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
