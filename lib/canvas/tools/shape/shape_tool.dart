import 'dart:math' as math;

import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_element_model.dart';
import 'package:beyond/foundation/resize_handle.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _shapeStrokeWidth = 2.0;

Path shapePath(ShapeKind kind, Rect rect) => switch (kind) {
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
};

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
  const ShapePreview({required this.kind, required this.rect});

  final ShapeKind kind;
  final Rect rect;
}

class ShapeTool extends ChangeNotifier {
  ShapeTool({required this.onShape});

  final ValueChanged<ShapeModel> onShape;
  final _uuid = const Uuid();
  ShapeKind _kind = ShapeKind.roundedRectangle;
  int? _pointer;
  Offset? _start;
  Offset? _end;

  ShapeKind get kind => _kind;

  ShapePreview? get preview {
    final start = _start;
    final end = _end;
    if (start == null || end == null) return null;
    return ShapePreview(kind: _kind, rect: Rect.fromPoints(start, end));
  }

  void setKind(ShapeKind kind) {
    if (_kind == kind) return;
    _kind = kind;
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
          label: switch (model.data.kind) {
            ShapeKind.roundedRectangle => 'Rounded rectangle',
            ShapeKind.ellipse => 'Ellipse',
            ShapeKind.diamond => 'Diamond',
          },
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
                          : colors.textSecondary,
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
    required this.color,
  });

  final ShapePreview preview;
  final Offset canvasOffset;
  final double canvasScale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(
      (preview.rect.topLeft - canvasOffset) * canvasScale,
      (preview.rect.bottomRight - canvasOffset) * canvasScale,
    );
    canvas.drawPath(
      shapePath(preview.kind, rect),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _shapeStrokeWidth * canvasScale,
    );
  }

  @override
  bool shouldRepaint(ShapePreviewPainter oldDelegate) =>
      oldDelegate.preview.kind != preview.kind ||
      oldDelegate.preview.rect != preview.rect ||
      oldDelegate.canvasOffset != canvasOffset ||
      oldDelegate.canvasScale != canvasScale ||
      oldDelegate.color != color;
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter({required this.path, required this.color});

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _shapeStrokeWidth,
    );
  }

  @override
  bool hitTest(Offset position) => path.contains(position);

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.color != color;
}

class _ShapeDrag extends Drag {
  _ShapeDrag(this.onUpdate);

  final ValueChanged<Offset> onUpdate;

  @override
  void update(DragUpdateDetails details) => onUpdate(details.delta);
}
