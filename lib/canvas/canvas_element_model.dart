// Defines the shared mutable model contract for canvas elements.
// Extended by each interactive element tool and renderer.

import 'package:beyond/canvas/canvas_document.dart';
import 'package:flutter/material.dart';

// ---------- Model contract ----------

/// Adds selection and canvas geometry behavior to persisted element data.
/// Extended by each concrete interactive canvas element model.
abstract class CanvasElementModel<T extends CanvasElementData>
    extends ChangeNotifier {
  // ---------- Construction ----------

  CanvasElementModel(this.data);

  // ---------- State ----------

  final T data;
  bool _selected = false;

  bool get selected => _selected;

  set selected(bool value) {
    if (_selected == value) return;
    _selected = value;
    notifyListeners();
  }

  // ---------- Geometry ----------

  Offset get canvasPosition;

  Size get canvasSize;

  void moveBy(Offset delta);
}
