// Provides arrow geometry, editing state, rendering, and hit testing.
// Used by the canvas arrow creation and selection flows.

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_element_model.dart';
import 'package:beyond/ui/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

part 'arrow_geometry.dart';
part 'arrow_model.dart';
part 'arrow_preview.dart';
part 'arrow_view.dart';

// ---------- Tool state ----------

/// Tracks pointer input while creating arrows on the canvas.
/// Used by the canvas page to produce [ArrowModel] instances.
class ArrowTool extends ChangeNotifier {
  // ---------- Construction ----------

  ArrowTool({required this.onArrow});

  final ValueChanged<ArrowModel> onArrow;
  final _uuid = const Uuid();
  int? _pointer;
  String? _id;
  Offset? _start;
  Offset? _end;

  // ---------- Public API ----------

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
        control: arrowControlPoint(start: start, end: end),
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
    final arrow = id != null && start != null && end != null ? _newArrow(id, start, end) : null;
    _clearPreview();
    if (arrow != null) onArrow(arrow);
  }

  void onPointerCancel(PointerCancelEvent event) {
    if (!ownsPointer(event.pointer)) return;
    _clearPreview();
  }

  void cancel() {
    if (!isDrawing) return;
    _clearPreview();
  }

  // ---------- Private helpers ----------

  ArrowModel? _newArrow(String id, Offset start, Offset end) {
    if ((end - start).distance < arrowMinimumLength) return null;
    return ArrowModel(
      ArrowElementData(
        id: id,
        start: start,
        control: arrowControlPoint(start: start, end: end),
        end: end,
      ),
    );
  }

  void _clearPreview() {
    _pointer = null;
    _id = null;
    _start = null;
    _end = null;
    notifyListeners();
  }
}
