// Adapts persisted pen data to cached render geometry and movement.
// Used by canvas selection, rendering, hit testing, and persistence.

part of 'pen_tool.dart';

// ---------- Models ----------

/// Adapts persisted pen data to a rendered path and canvas movement.
/// Used by selection, hit testing, and stroke rendering.
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
