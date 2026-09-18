// Renders a loaded media image with selection and resize affordances.
// Used internally by the media tool after image resolution succeeds.

part of 'media_tool.dart';

// ---------- Image ----------

class _MediaImage extends StatefulWidget {
  const _MediaImage({
    required this.model,
    required this.onActivate,
    required this.onMove,
    required this.onResize,
  });

  final MediaModel model;
  final VoidCallback onActivate;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;

  @override
  State<_MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<_MediaImage> {
  Offset? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final model = widget.model;
    final image = model.image!;
    return SizedBox.fromSize(
      size: model.canvasSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onTap: widget.onActivate,
        onPanStart: (details) => _dragPosition = details.globalPosition,
        onPanUpdate: (details) {
          final position = details.globalPosition;
          widget.onMove(position - _dragPosition!);
          _dragPosition = position;
        },
        onPanEnd: (_) => _dragPosition = null,
        onPanCancel: () => _dragPosition = null,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: theme.geo.radiusSmall,
                child: Image(
                  key: const ValueKey('media-image'),
                  image: image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (model.selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: theme.geo.radiusSmall,
                      border: Border.all(color: colors.accent, width: 2),
                    ),
                  ),
                ),
              ),
            if (model.active)
              Positioned(
                right: 0,
                bottom: 0,
                child: ResizeHandle(
                  key: const ValueKey('media-resize-handle'),
                  semanticLabel: 'Resize media',
                  gestures: {
                    ImmediateMultiDragGestureRecognizer: immediateDragGestureFactory(
                      (_) => CallbackDrag(widget.onResize),
                    ),
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
