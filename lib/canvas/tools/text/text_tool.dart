// Renders and resizes a persisted canvas text tool element.
// Used by the canvas element stack for text display and editing.

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/widgets/pointer_scroll_boundary.dart';
import 'package:beyond/canvas/editor/widgets/resize_handle.dart';
import 'package:beyond/canvas/persistence/attachments/store.dart';
import 'package:beyond/canvas/tools/text/text_block_model.dart';
import 'package:beyond/canvas/tools/text/text_markdown_editor.dart';
import 'package:beyond/canvas/tools/text/text_markdown_preview.dart';
import 'package:beyond/theme/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

export 'text_block_controls.dart';
export 'text_block_model.dart';
export 'text_tool_settings.dart';

// ---------- Text tool ----------

/// Switches a text element between Markdown editing and preview surfaces.
/// Used by the canvas element stack with resize and selection chrome.
class TextTool extends StatelessWidget {
  const TextTool({
    required this.model,
    required this.attachmentStore,
    required this.onEdit,
    required this.onMove,
    required this.onResize,
    super.key,
  });

  final TextBlockModel model;
  final AttachmentStore attachmentStore;
  final VoidCallback onEdit;
  final ValueChanged<Offset> onMove;
  final void Function(Size renderedSize, Offset delta) onResize;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    return Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) {
          final body = model.editing
              ? TextMarkdownEditor(model: model, attachmentStore: attachmentStore)
              : TextMarkdownPreview(
                  source: model.node.markdown,
                  style: model.style,
                  scrollController: model.node.height == null ? null : model.scrollController,
                  onEdit: onEdit,
                  onMove: onMove,
                  attachmentStore: attachmentStore,
                );
          final configuredBody = ScrollConfiguration(
            behavior: const _TextBlockScrollBehavior(),
            child: body,
          );
          final visibleBody = model.node.height == null
              ? configuredBody
              : Scrollbar(
                  controller: model.scrollController,
                  thumbVisibility: true,
                  child: PointerScrollBoundary(child: configuredBody),
                );
          final resizeGestureFactory = GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
            ImmediateMultiDragGestureRecognizer.new,
            (recognizer) {
              recognizer.onStart = (_) => _TextBlockResizeDrag(
                (delta) => onResize(context.size!, delta),
              );
            },
          );
          const resizeRecognizer = ImmediateMultiDragGestureRecognizer;
          return Semantics(
            container: true,
            selected: model.selected,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: model.selected ? colors.accentSoft : Colors.transparent,
                border: model.selected ? Border.all(color: colors.accent, width: 2) : null,
                borderRadius: theme.geo.radiusSmall,
              ),
              child: CompositedTransformTarget(
                link: model.layerLink,
                child: SizedBox(
                  width: model.node.width,
                  height: model.node.height,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: textNodeMinimumHeight),
                    child: Stack(
                      children: [
                        if (model.node.height != null) Positioned.fill(child: visibleBody) else visibleBody,
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              reverseDuration: const Duration(milliseconds: 180),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                              child: model.editing
                                  ? SizedBox.expand(
                                      key: const ValueKey('text-block-editing-border'),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: theme.geo.radiusSmall,
                                          border: Border.all(color: colors.border),
                                        ),
                                      ),
                                    )
                                  : const SizedBox(
                                      key: ValueKey('text-block-editing-border-hidden'),
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: SizedBox(
                            width: 32,
                            height: 20,
                            child: IgnorePointer(
                              ignoring: !model.editing,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                reverseDuration: const Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeOutCubic,
                                transitionBuilder: _resizeHandleTransition,
                                child: model.editing
                                    ? TextFieldTapRegion(
                                        child: ResizeHandle(
                                          key: const ValueKey('text-block-resize-handle'),
                                          semanticLabel: 'Resize text block',
                                          gestures: {resizeRecognizer: resizeGestureFactory},
                                        ),
                                      )
                                    : const SizedBox(
                                        key: ValueKey('text-block-resize-handle-hidden'),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------- Scrolling and transitions ----------

class _TextBlockScrollBehavior extends MaterialScrollBehavior {
  const _TextBlockScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

Widget _resizeHandleTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
      alignment: Alignment.bottomRight,
      child: child,
    ),
  );
}

// ---------- Gestures ----------

class _TextBlockResizeDrag extends Drag {
  _TextBlockResizeDrag(this.onResize);

  final ValueChanged<Offset> onResize;

  @override
  void update(DragUpdateDetails details) => onResize(details.delta);
}
