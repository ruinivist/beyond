// Renders movement and rotation controls for an edited text block.
// Used by the canvas overlay while a text tool element is being edited.

import 'dart:math' as math;

import 'package:beyond/canvas/tools/text/text_block_model.dart';
import 'package:beyond/ui/common/b_icon_drag.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ---------- Controls ----------

/// Presents drag handles for moving and rotating the active text element.
/// Used by the editor's composited text-controls overlay.
class TextBlockControls extends StatelessWidget {
  const TextBlockControls({
    required this.model,
    required this.onMove,
    required this.onRotate,
    required this.onTransformStart,
    required this.onTransformEnd,
    required this.rotationCenter,
    super.key,
  });

  final TextBlockModel model;
  final ValueChanged<Offset> onMove;
  final ValueChanged<double> onRotate;
  final VoidCallback onTransformStart;
  final VoidCallback onTransformEnd;
  final ValueGetter<Offset> rotationCenter;

  static const size = Size(40, 88);
  static const followerOffset = Offset(-50, 24);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: TextFieldTapRegion(
        child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BIconDrag(
              key: const ValueKey('text-block-handle'),
              semanticLabel: 'Move text block',
              onDragStart: (_) {
                onTransformStart();
                return _TextBlockDrag(onMove, onTransformEnd);
              },
              icon: const Icon(Icons.drag_indicator),
            ),
            BIconDrag(
              key: const ValueKey('text-block-rotate-control'),
              semanticLabel: 'Rotate text block',
              onDragStart: (position) {
                onTransformStart();
                return _TextBlockRotateDrag(
                  startPosition: position,
                  center: rotationCenter(),
                  rotation: model.node.rotation,
                  onRotate: onRotate,
                  onEnd: onTransformEnd,
                );
              },
              icon: const Icon(Icons.rotate_right),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Gestures ----------

class _TextBlockDrag extends Drag {
  _TextBlockDrag(this.onMove, this.onEnd);

  final ValueChanged<Offset> onMove;
  final VoidCallback onEnd;

  @override
  void update(DragUpdateDetails details) => onMove(details.delta);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onEnd();
}

class _TextBlockRotateDrag extends Drag {
  _TextBlockRotateDrag({
    required Offset startPosition,
    required this.center,
    required this._rotation,
    required this.onRotate,
    required this.onEnd,
  }) : _lastPointerAngle = _pointerAngle(startPosition, center);

  final Offset center;
  final ValueChanged<double> onRotate;
  final VoidCallback onEnd;
  double _lastPointerAngle;
  double _rotation;

  @override
  void update(DragUpdateDetails details) {
    final pointerAngle = _pointerAngle(details.globalPosition, center);
    var delta = pointerAngle - _lastPointerAngle;
    if (delta > math.pi) delta -= math.pi * 2;
    if (delta < -math.pi) delta += math.pi * 2;
    _rotation += delta;
    _lastPointerAngle = pointerAngle;
    onRotate(_rotation);
  }

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onEnd();
}

// ---------- Helpers ----------

double _pointerAngle(Offset pointer, Offset center) => math.atan2(pointer.dy - center.dy, pointer.dx - center.dx);
