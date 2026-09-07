import 'dart:math' as math;

import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_element_model.dart';
import 'package:beyond/foundation/resize_handle.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

Path shapePath(ShapeKind kind, Rect rect) => switch (kind) {
  ShapeKind.rectangle => Path()..addRect(rect),
  ShapeKind.roundedRectangle =>
    Path()..addRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(math.min(16, rect.shortestSide / 2)),
      ),
    ),
  ShapeKind.ellipse => Path()..addOval(rect),
  ShapeKind.diamond =>
    Path()
      ..moveTo(rect.center.dx, rect.top)
      ..lineTo(rect.right, rect.center.dy)
      ..lineTo(rect.center.dx, rect.bottom)
      ..lineTo(rect.left, rect.center.dy)
      ..close(),
  ShapeKind.triangle =>
    Path()
      ..moveTo(rect.center.dx, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close(),
  ShapeKind.hexagon =>
    Path()
      ..moveTo(rect.left + rect.width * 0.25, rect.top)
      ..lineTo(rect.left + rect.width * 0.75, rect.top)
      ..lineTo(rect.right, rect.center.dy)
      ..lineTo(rect.left + rect.width * 0.75, rect.bottom)
      ..lineTo(rect.left + rect.width * 0.25, rect.bottom)
      ..lineTo(rect.left, rect.center.dy)
      ..close(),
};

extension ShapeKindLabel on ShapeKind {
  String get label => switch (this) {
    ShapeKind.rectangle => 'Rectangle',
    ShapeKind.roundedRectangle => 'Rounded rectangle',
    ShapeKind.ellipse => 'Ellipse',
    ShapeKind.diamond => 'Diamond',
    ShapeKind.triangle => 'Triangle',
    ShapeKind.hexagon => 'Hexagon',
  };
}

class ShapeModel extends CanvasElementModel<ShapeElementData> {
  ShapeModel(super.data);

  bool _active = false;

  bool get active => _active;

  set active(bool value) {
    if (_active == value) return;
    _active = value;
    notifyListeners();
  }

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

  void resizeBy(Offset delta) {
    final size = Size(
      math.max(shapeMinimumSize.width, data.size.width + delta.dx),
      math.max(shapeMinimumSize.height, data.size.height + delta.dy),
    );
    if (size == data.size) return;
    data.size = size;
    notifyListeners();
  }
}

class ShapePreview {
  const ShapePreview({
    required this.kind,
    required this.rect,
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  final ShapeKind kind;
  final Rect rect;
  final Color strokeColor;
  final Color? fillColor;
  final double strokeWidth;
}

class ShapeTool extends ChangeNotifier {
  ShapeTool({required this.onShape});

  final ValueChanged<ShapeModel> onShape;
  final _uuid = const Uuid();
  ShapeKind _kind = ShapeKind.roundedRectangle;
  Color _strokeColor = Colors.black;
  Color? _fillColor;
  double _strokeWidth = 2;
  int? _pointer;
  Offset? _start;
  Offset? _end;

  ShapeKind get kind => _kind;
  Color get strokeColor => _strokeColor;
  Color? get fillColor => _fillColor;
  double get strokeWidth => _strokeWidth;

  ShapePreview? get preview {
    final start = _start;
    final end = _end;
    if (start == null || end == null) return null;
    return ShapePreview(
      kind: _kind,
      rect: Rect.fromPoints(start, end),
      strokeColor: _strokeColor,
      fillColor: _fillColor,
      strokeWidth: _strokeWidth,
    );
  }

  void setKind(ShapeKind kind) {
    if (_kind == kind) return;
    _kind = kind;
    notifyListeners();
  }

  void setStrokeColor(Color color) {
    if (_strokeColor == color) return;
    _strokeColor = color;
    notifyListeners();
  }

  void setFillColor(Color? color) {
    if (_fillColor == color) return;
    _fillColor = color;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    if (_strokeWidth == width) return;
    _strokeWidth = width;
    notifyListeners();
  }

  bool ownsPointer(int pointer) => _pointer == pointer;

  void onPointerDown(PointerDownEvent event, Offset canvasPosition) {
    if (event.buttons != kPrimaryButton || _pointer != null) return;
    _pointer = event.pointer;
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
    final preview = this.preview;
    _clearPreview();
    if (preview == null ||
        preview.rect.width < shapeMinimumSize.width ||
        preview.rect.height < shapeMinimumSize.height) {
      return;
    }
    onShape(
      ShapeModel(
        ShapeElementData(
          id: _uuid.v4(),
          kind: preview.kind,
          position: preview.rect.topLeft,
          size: preview.rect.size,
          strokeColor: preview.strokeColor.toARGB32(),
          fillColor: preview.fillColor?.toARGB32(),
          strokeWidth: preview.strokeWidth,
        ),
      ),
    );
  }

  void onPointerCancel(PointerCancelEvent event) {
    if (ownsPointer(event.pointer)) _clearPreview();
  }

  void cancel() {
    if (_pointer != null) _clearPreview();
  }

  void _clearPreview() {
    _pointer = null;
    _start = null;
    _end = null;
    notifyListeners();
  }
}

class Shape extends StatelessWidget {
  const Shape({
    required this.model,
    required this.onMove,
    required this.onResize,
    super.key,
  });

  final ShapeModel model;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;

  @override
  Widget build(BuildContext context) {
    final colors = BTheme.of(context).colors;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => SizedBox.fromSize(
        size: model.canvasSize,
        child: Semantics(
          container: true,
          label: model.data.kind.label,
          selected: model.selected,
          child: RawGestureDetector(
            gestures: {
              ImmediateMultiDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    ImmediateMultiDragGestureRecognizer
                  >(
                    ImmediateMultiDragGestureRecognizer.new,
                    (recognizer) {
                      recognizer.onStart = (_) => _ShapeDrag(onMove);
                    },
                  ),
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ShapePainter(
                      path: shapePath(
                        model.data.kind,
                        Offset.zero & model.canvasSize,
                      ),
                      color: model.selected || model.active
                          ? colors.accent
                          : Color(model.data.strokeColor),
                      fillColor: model.data.fillColor == null
                          ? null
                          : Color(model.data.fillColor!),
                      strokeWidth: model.data.strokeWidth,
                    ),
                  ),
                ),
                if (model.selected || model.active)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: ResizeHandle(
                      key: const ValueKey('shape-resize-handle'),
                      semanticLabel: 'Resize shape',
                      gestures: {
                        ImmediateMultiDragGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                              ImmediateMultiDragGestureRecognizer
                            >(
                              ImmediateMultiDragGestureRecognizer.new,
                              (recognizer) {
                                recognizer.onStart = (_) =>
                                    _ShapeDrag(onResize);
                              },
                            ),
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShapePreviewPainter extends CustomPainter {
  const ShapePreviewPainter({
    required this.preview,
    required this.canvasOffset,
    required this.canvasScale,
  });

  final ShapePreview preview;
  final Offset canvasOffset;
  final double canvasScale;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(
      (preview.rect.topLeft - canvasOffset) * canvasScale,
      (preview.rect.bottomRight - canvasOffset) * canvasScale,
    );
    final path = shapePath(preview.kind, rect);
    if (preview.fillColor case final fill?) {
      canvas.drawPath(path, Paint()..color = fill);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = preview.strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = preview.strokeWidth * canvasScale,
    );
  }

  @override
  bool shouldRepaint(ShapePreviewPainter oldDelegate) =>
      oldDelegate.preview.kind != preview.kind ||
      oldDelegate.preview.rect != preview.rect ||
      oldDelegate.canvasOffset != canvasOffset ||
      oldDelegate.canvasScale != canvasScale ||
      oldDelegate.preview.strokeColor != preview.strokeColor ||
      oldDelegate.preview.fillColor != preview.fillColor ||
      oldDelegate.preview.strokeWidth != preview.strokeWidth;
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter({
    required this.path,
    required this.color,
    required this.fillColor,
    required this.strokeWidth,
  });

  final Path path;
  final Color color;
  final Color? fillColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (fillColor case final fillColor?) {
      canvas.drawPath(path, Paint()..color = fillColor);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool hitTest(Offset position) => path.contains(position);

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _ShapeDrag extends Drag {
  _ShapeDrag(this.onUpdate);

  final ValueChanged<Offset> onUpdate;

  @override
  void update(DragUpdateDetails details) => onUpdate(details.delta);
}
