// Adapts persisted arrow data to selectable canvas geometry.
// Used by the editor's element, movement, and rendering flows.

part of 'arrow_tool.dart';

// ---------- Models ----------

/// Identifies one editable point on a quadratic arrow.
enum ArrowPoint { start, control, end }

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

  Offset point(ArrowPoint point) => switch (point) {
    ArrowPoint.start => data.start,
    ArrowPoint.control => data.control,
    ArrowPoint.end => data.end,
  };

  bool setPoint(ArrowPoint point, Offset position) {
    final next = switch (point) {
      ArrowPoint.start => _minimumLengthPoint(position, data.end, data.start),
      ArrowPoint.control => position,
      ArrowPoint.end => _minimumLengthPoint(position, data.start, data.end),
    };
    if (next == this.point(point)) return false;
    switch (point) {
      case ArrowPoint.start:
        data.start = next;
      case ArrowPoint.control:
        data.control = next;
      case ArrowPoint.end:
        data.end = next;
    }
    notifyDocumentChanged();
    return true;
  }

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

Offset _minimumLengthPoint(Offset requested, Offset fixed, Offset current) {
  final vector = requested - fixed;
  if (vector.distance >= arrowMinimumLength) return requested;
  final fallback = current - fixed;
  final direction = vector == Offset.zero ? fallback / fallback.distance : vector / vector.distance;
  return fixed + direction * (arrowMinimumLength + 1e-6);
}
