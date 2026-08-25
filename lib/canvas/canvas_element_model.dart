import 'package:beyond/canvas/canvas_document.dart';
import 'package:flutter/material.dart';

abstract class CanvasElementModel<T extends CanvasElementData>
    extends ChangeNotifier {
  CanvasElementModel(this.data);

  final T data;
  bool _selected = false;

  bool get selected => _selected;

  set selected(bool value) {
    if (_selected == value) return;
    _selected = value;
    notifyListeners();
  }

  Offset get canvasPosition;

  Size get canvasSize;

  void moveBy(Offset delta);
}
