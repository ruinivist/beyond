// Describes and paints an arrow while it is being drawn.
// Used by the arrow tool and the canvas preview overlay.

part of 'arrow_tool.dart';

/// Describes an in-progress arrow before it becomes persisted.
typedef ArrowPreview = ({
  ArrowGeometry geometry,
  Color color,
  ArrowStrokeStyle strokeStyle,
  double strokeWidth,
  bool showControls,
});

// ---------- Painters ----------

/// Paints an in-progress arrow in screen coordinates.
/// Used by the canvas overlay while [ArrowTool] owns a pointer.
class ArrowPreviewPainter extends CustomPainter {
  const ArrowPreviewPainter({
    required this.preview,
    required this.guideColor,
    required this.canvasOffset,
    required this.canvasScale,
  });

  final ArrowPreview preview;
  final Color guideColor;
  final Offset canvasOffset;
  final double canvasScale;

  @override
  void paint(Canvas canvas, Size size) {
    final screenGeometry = ArrowGeometry(
      start: _toScreen(preview.geometry.start),
      controls: preview.geometry.controls.map(_toScreen).toList(),
      end: _toScreen(preview.geometry.end),
    );
    if (preview.showControls) {
      _ArrowGuidePainter(
        points: [screenGeometry.start, ...screenGeometry.controls, screenGeometry.end],
        color: guideColor.withValues(alpha: 0.55),
      ).paint(canvas, size);
      final paint = Paint()..color = guideColor;
      for (final control in screenGeometry.controls) {
        canvas.drawCircle(control, _ArrowPointHandle.visualSize / 2, paint);
      }
    }
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
        !listEquals(oldDelegate.preview.geometry.controls, preview.geometry.controls) ||
        oldDelegate.preview.geometry.end != preview.geometry.end ||
        oldDelegate.canvasOffset != canvasOffset ||
        oldDelegate.canvasScale != canvasScale ||
        oldDelegate.preview.color != preview.color ||
        oldDelegate.preview.strokeStyle != preview.strokeStyle ||
        oldDelegate.preview.strokeWidth != preview.strokeWidth ||
        oldDelegate.preview.showControls != preview.showControls ||
        oldDelegate.guideColor != guideColor;
  }
}
