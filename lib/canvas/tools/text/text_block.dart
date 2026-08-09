import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class TextBlockModel {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class TextBlock extends StatelessWidget {
  const TextBlock({
    required this.model,
    required this.onSelect,
    required this.onMove,
    super.key,
  });

  final TextBlockModel model;
  final ValueChanged<PointerDownEvent> onSelect;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final block = appTheme.components.block;
    final editorial = appTheme.typography.editorial;
    return Listener(
      onPointerDown: onSelect,
      child: SizedBox(
        width: 280,
        child: Material(
          type: MaterialType.transparency,
          child: ListenableBuilder(
            listenable: model.focusNode,
            builder: (context, _) {
              final focused = model.focusNode.hasFocus;
              return Stack(
                children: [
                  TextField(
                    controller: model.controller,
                    focusNode: model.focusNode,
                    maxLines: null,
                    cursorColor: block.selectedBorder,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(12, 12, 28, 12),
                      hintText: 'Type something',
                      hintStyle: editorial.bodyLarge!.copyWith(
                        color: block.mutedForeground,
                      ),
                    ),
                    style: editorial.bodyLarge!.copyWith(
                      color: block.foreground,
                      fontSize: 20,
                      height: 1.3,
                    ),
                  ),
                  if (focused)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 28,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: TextFieldTapRegion(
                          child: Semantics(
                            button: true,
                            label: 'Move text block',
                            child: RawGestureDetector(
                              key: const ValueKey('text-block-handle'),
                              behavior: HitTestBehavior.opaque,
                              gestures: {
                                ImmediateMultiDragGestureRecognizer:
                                    GestureRecognizerFactoryWithHandlers<
                                      ImmediateMultiDragGestureRecognizer
                                    >(ImmediateMultiDragGestureRecognizer.new, (
                                      recognizer,
                                    ) {
                                      recognizer.onStart = (_) =>
                                          _TextBlockDrag(onMove);
                                    }),
                              },
                              child: Center(
                                child: Icon(
                                  Icons.drag_indicator,
                                  size: 18,
                                  color: block.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TextBlockDrag extends Drag {
  _TextBlockDrag(this.onMove);

  final ValueChanged<Offset> onMove;

  @override
  void update(DragUpdateDetails details) => onMove(details.delta);
}
