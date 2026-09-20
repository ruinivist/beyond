// Adapts persisted arrow data to selectable canvas geometry.
// Used by the editor's element, movement, and rendering flows.

part of 'arrow_tool.dart';

// ---------- Models ----------

/// Adapts persisted arrow points to canvas geometry and movement.
/// Used by the canvas selection and arrow rendering flows.
class ArrowModel extends CanvasElementModel<ArrowElementData> {
  ArrowModel(super.data);

  ArrowGeometry get geometry => ArrowGeometry(
    start: data.start,
    control: data.control,
    end: data.end,
  );

  Rect get bounds => geometry.bounds;

  ArrowGeometry get localGeometry => geometry.shift(-bounds.topLeft);

  @override
  Offset get canvasPosition => bounds.topLeft;

  @override
  Size get canvasSize => bounds.size;

  Offset get start => geometry.start;

  Offset get control => geometry.control;

  Offset get end => geometry.end;

  Color get color => Color(data.color);

  set color(Color value) {
    final color = value.toARGB32();
    if (data.color == color) return;
    data.color = color;
    notifyDocumentChanged();
  }

  ArrowStrokeStyle get strokeStyle => data.strokeStyle;

  set strokeStyle(ArrowStrokeStyle value) {
    if (data.strokeStyle == value) return;
    data.strokeStyle = value;
    notifyDocumentChanged();
  }

  double get strokeWidth => data.strokeWidth;

  set strokeWidth(double value) {
    if (data.strokeWidth == value) return;
    data.strokeWidth = value;
    notifyDocumentChanged();
  }

  @override
  void moveBy(Offset delta) {
    if (delta == Offset.zero) return;
    data
      ..start += delta
      ..control += delta
      ..end += delta;
    notifyDocumentChanged();
  }
}
