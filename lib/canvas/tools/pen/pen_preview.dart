// Paints the active freehand stroke and pointer-width indicator.
// Used by the canvas overlay while the pen tool is enabled.

part of 'pen_tool.dart';

// ---------- Preview ----------

/// Repaints live pen samples and the current pointer indicator.
/// Used by the editor's full-canvas pen preview layer.
class PenPreviewPainter extends CustomPainter {
  PenPreviewPainter({required this.tool, required this.color}) : super(repaint: tool);

  final PenTool tool;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      createPenPath(tool._points, tool._strokeWidth),
      Paint()
        ..color = tool._color
        ..style = PaintingStyle.fill,
    );
    if (tool._pointerPosition case final pointer?) {
      canvas.drawCircle(
        pointer,
        tool._strokeWidth / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(PenPreviewPainter oldDelegate) => false;
}
