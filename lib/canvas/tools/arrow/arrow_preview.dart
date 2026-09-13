// Describes and paints an arrow while it is being drawn.
// Used by the arrow tool and the canvas preview overlay.

part of 'arrow_tool.dart';

// ---------- Painters ----------

/// Paints an in-progress arrow in screen coordinates.
/// Used by the canvas overlay while [ArrowTool] owns a pointer.
class ArrowPreviewPainter extends CustomPainter {
  const ArrowPreviewPainter({
    required this.geometry,
    required this.canvasOffset,
    required this.canvasScale,
    required this.color,
  });

  final ArrowGeometry geometry;
  final Offset canvasOffset;
  final double canvasScale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final screenGeometry = ArrowGeometry(
      start: _toScreen(geometry.start),
      control: _toScreen(geometry.control),
      end: _toScreen(geometry.end),
    );
    paintArrow(
      canvas,
      geometry: screenGeometry,
      color: color,
      strokeWidth: _arrowStrokeWidth * canvasScale,
    );
  }

  Offset _toScreen(Offset point) => (point - canvasOffset) * canvasScale;

  @override
  bool shouldRepaint(ArrowPreviewPainter oldDelegate) {
    return oldDelegate.geometry.start != geometry.start ||
        oldDelegate.geometry.control != geometry.control ||
        oldDelegate.geometry.end != geometry.end ||
        oldDelegate.canvasOffset != canvasOffset ||
        oldDelegate.canvasScale != canvasScale ||
        oldDelegate.color != color;
  }
}
