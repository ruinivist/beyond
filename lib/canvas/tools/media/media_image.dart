// Renders a loaded media image with selection and resize affordances.
// Used internally by the media tool after image resolution succeeds.

part of 'media_tool.dart';

// ---------- Image ----------

class _MediaImage extends StatelessWidget {
  const _MediaImage({
    required this.model,
    required this.onMove,
    required this.onResize,
  });

  final MediaModel model;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final image = model.image!;
    return SizedBox.fromSize(
      size: model.canvasSize,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          ImmediateMultiDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
                ImmediateMultiDragGestureRecognizer.new,
                (recognizer) {
                  recognizer.onStart = (_) => _MediaDrag(onMove);
                },
              ),
        },
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
                    ImmediateMultiDragGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
                          ImmediateMultiDragGestureRecognizer.new,
                          (recognizer) {
                            recognizer.onStart = (_) => _MediaDrag(onResize);
                          },
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
