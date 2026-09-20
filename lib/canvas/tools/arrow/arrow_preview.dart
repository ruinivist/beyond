// Describes and paints an arrow while it is being drawn.
// Used by the arrow tool and the canvas preview overlay.

part of 'arrow_tool.dart';

/// Describes an in-progress arrow before it becomes persisted.
typedef ArrowPreview = ({
  ArrowGeometry geometry,
  Color color,
  ArrowStrokeStyle strokeStyle,
  double strokeWidth,
});

// ---------- Painters ----------

/// Paints an in-progress arrow in screen coordinates.
/// Used by the canvas overlay while [ArrowTool] owns a pointer.
class ArrowPreviewPainter extends CustomPainter {
  const ArrowPreviewPainter({
    required this.preview,
    required this.canvasOffset,
    required this.canvasScale,
  });

  final ArrowPreview preview;
  final Offset canvasOffset;
  final double canvasScale;

  @override
  void paint(Canvas canvas, Size size) {
    final screenGeometry = ArrowGeometry(
      start: _toScreen(preview.geometry.start),
      control: _toScreen(preview.geometry.control),
      end: _toScreen(preview.geometry.end),
    );
    paintArrow(
      canvas,
      geometry: screenGeometry,
      color: preview.color,
      strokeStyle: preview.strokeStyle,
      strokeWidth: preview.strokeWidth * canvasScale,
      dashScale: canvasScale,
    );
  }

  Offset _toScreen(Offset point) => (point - canvasOffset) * canvasScale;

  @override
  bool shouldRepaint(ArrowPreviewPainter oldDelegate) {
    return oldDelegate.preview.geometry.start != preview.geometry.start ||
        oldDelegate.preview.geometry.control != preview.geometry.control ||
        oldDelegate.preview.geometry.end != preview.geometry.end ||
        oldDelegate.canvasOffset != canvasOffset ||
        oldDelegate.canvasScale != canvasScale ||
        oldDelegate.preview.color != preview.color ||
        oldDelegate.preview.strokeStyle != preview.strokeStyle ||
        oldDelegate.preview.strokeWidth != preview.strokeWidth;
  }
}
