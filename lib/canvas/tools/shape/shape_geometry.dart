// Builds paths and user-facing labels for supported canvas shapes.
// Used by shape previews, persisted rendering, semantics, and hit testing.

part of 'shape_tool.dart';

// ---------- Geometry ----------

/// Builds a closed path for a shape kind inside the supplied bounds.
/// Used by preview and persisted-shape painters.
Path shapePath(ShapeKind kind, Rect rect) => switch (kind) {
  ShapeKind.rectangle => Path()..addRect(rect),
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
  ShapeKind.triangle =>
    Path()
      ..moveTo(rect.center.dx, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close(),
  ShapeKind.hexagon =>
    Path()
      ..moveTo(rect.left + rect.width * 0.25, rect.top)
      ..lineTo(rect.left + rect.width * 0.75, rect.top)
      ..lineTo(rect.right, rect.center.dy)
      ..lineTo(rect.left + rect.width * 0.75, rect.bottom)
      ..lineTo(rect.left + rect.width * 0.25, rect.bottom)
      ..lineTo(rect.left, rect.center.dy)
      ..close(),
};

// ---------- Labels ----------

/// Maps persisted shape kinds to concise user-facing labels.
/// Used by shape semantics and tool option controls.
extension ShapeKindLabel on ShapeKind {
  String get label => switch (this) {
    ShapeKind.rectangle => 'Rectangle',
    ShapeKind.roundedRectangle => 'Rounded rectangle',
    ShapeKind.ellipse => 'Ellipse',
    ShapeKind.diamond => 'Diamond',
    ShapeKind.triangle => 'Triangle',
    ShapeKind.hexagon => 'Hexagon',
  };
}
