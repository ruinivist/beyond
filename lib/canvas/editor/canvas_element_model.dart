// Defines the shared mutable model contract for canvas elements.
// Extended by each interactive element tool and renderer.

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:flutter/material.dart';

// ---------- Model contract ----------

/// Adds selection and canvas geometry behavior to persisted element data.
/// Extended by each concrete interactive canvas element model.
abstract class CanvasElementModel<T extends CanvasElementData> extends ChangeNotifier {
  // ---------- Construction ----------

  CanvasElementModel(this.data);

  // ---------- State ----------

  final T data;
  final ValueNotifier<int> _documentRevision = ValueNotifier(0);
  bool _selected = false;
  bool _active = false;

  Listenable get documentChanges => _documentRevision;

  @protected
  void notifyDocumentChanged({bool rebuild = true}) {
    _documentRevision.value++;
    if (rebuild) notifyListeners();
  }

  bool get selected => _selected;

  set selected(bool value) {
    if (_selected == value) return;
    _selected = value;
    notifyListeners();
  }

  bool get active => _active;

  set active(bool value) {
    if (_active == value) return;
    _active = value;
    notifyListeners();
  }

  // ---------- Geometry ----------

  Offset get canvasPosition;

  Size get canvasSize;

  void moveBy(Offset delta);

  @override
  void dispose() {
    _documentRevision.dispose();
    super.dispose();
  }
}

/// Adds center rotation and a composited anchor to canvas element models.
/// Used by elements that share the editor's floating transform controls.
abstract class RotatableCanvasElementModel<T extends CanvasElementData> extends CanvasElementModel<T> {
  RotatableCanvasElementModel(super.data);

  final layerLink = LayerLink();

  double get rotation;

  void rotate(double angle);
}

// ---------- Geometry helpers ----------

double distanceToSegmentSquared(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.distanceSquared;
  if (lengthSquared == 0) return (point - start).distanceSquared;
  final offset = point - start;
  final ratio = ((offset.dx * segment.dx + offset.dy * segment.dy) / lengthSquared).clamp(
    0.0,
    1.0,
  );
  return (point - (start + segment * ratio)).distanceSquared;
}
