// Adapts persisted shape data to selectable and resizable canvas state.
// Used by shape rendering, selection, transformation, and persistence flows.

part of 'shape_tool.dart';

// ---------- Models ----------

/// Adapts persisted shape data to selectable and resizable canvas geometry.
/// Used by the canvas selection and shape rendering flows.
class ShapeModel extends CanvasElementModel<ShapeElementData> {
  ShapeModel(super.data);

  @override
  Offset get canvasPosition => data.position;

  @override
  Size get canvasSize => data.size;

  @override
  void moveBy(Offset delta) {
    if (delta == Offset.zero) return;
    data.position += delta;
    notifyDocumentChanged();
  }

  void resizeBy(Offset delta) {
    final size = Size(
      math.max(shapeMinimumSize.width, data.size.width + delta.dx),
      math.max(shapeMinimumSize.height, data.size.height + delta.dy),
    );
    if (size == data.size) return;
    data.size = size;
    notifyDocumentChanged();
  }
}
