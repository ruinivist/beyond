import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import 'code_language.dart';

const codeBlockMinimumSize = Size(280, 240);

class CodeBlockModel extends ChangeNotifier {
  CodeBlockModel(Size size) : _size = _clampSize(size);

  Size _size;
  bool _selected = false;
  final controller = CodeLineEditingController(
    options: const CodeLineOptions(indentSize: 2),
  );
  final focusNode = FocusNode();
  CodeLanguage _language = CodeLanguage.dart;

  Size get size => _size;

  bool get selected => _selected;

  set selected(bool value) {
    if (_selected == value) return;
    _selected = value;
    notifyListeners();
  }

  set size(Size value) {
    final nextSize = _clampSize(value);
    if (_size == nextSize) return;
    _size = nextSize;
    notifyListeners();
  }

  CodeLanguage get language => _language;

  set language(CodeLanguage value) {
    if (_language == value) return;
    _language = value;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

Size _clampSize(Size size) {
  return Size(
    math.max(codeBlockMinimumSize.width, size.width),
    math.max(codeBlockMinimumSize.height, size.height),
  );
}

class CodeBlock extends StatelessWidget {
  const CodeBlock({
    required this.model,
    required this.onSelect,
    required this.onMove,
    super.key,
  });

  final CodeBlockModel model;
  final ValueChanged<PointerDownEvent> onSelect;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: onSelect,
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) => SizedBox.fromSize(
          size: model.size,
          child: Material(
            color: const Color(0xff282c34),
            elevation: model.selected ? 12 : 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: model.selected
                  ? BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  children: [
                    _CodeBlockHeader(model: model, onMove: onMove),
                    const Divider(height: 1, color: Colors.white12),
                    Expanded(
                      child: CodeEditor(
                        controller: model.controller,
                        focusNode: model.focusNode,
                        wordWrap: false,
                        autocompleteSymbols: true,
                        padding: const EdgeInsets.all(8),
                        style: CodeEditorStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontHeight: 1.4,
                          textColor: const Color(0xffabb2bf),
                          backgroundColor: const Color(0xff282c34),
                          cursorLineColor: Colors.white.withValues(alpha: 0.04),
                          codeTheme: model.language.theme,
                        ),
                        indicatorBuilder:
                            (context, controller, chunkController, notifier) =>
                                Row(
                                  children: [
                                    DefaultCodeLineNumber(
                                      controller: controller,
                                      notifier: notifier,
                                    ),
                                    DefaultCodeChunkIndicator(
                                      width: 16,
                                      controller: chunkController,
                                      notifier: notifier,
                                    ),
                                  ],
                                ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _CodeBlockResizeHandle(model: model),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlockResizeHandle extends StatelessWidget {
  const _CodeBlockResizeHandle({required this.model});

  final CodeBlockModel model;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: Semantics(
        button: true,
        label: 'Resize code block',
        child: GestureDetector(
          key: const ValueKey('code-block-resize-handle'),
          behavior: HitTestBehavior.opaque,
          onScaleUpdate: (details) {
            model.size = Size(
              model.size.width + details.focalPointDelta.dx,
              model.size.height + details.focalPointDelta.dy,
            );
          },
          child: const SizedBox(
            width: 28,
            height: 28,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.open_in_full,
                  size: 16,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlockHeader extends StatelessWidget {
  const _CodeBlockHeader({required this.model, required this.onMove});

  final CodeBlockModel model;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: RawGestureDetector(
          key: const ValueKey('code-block-header'),
          behavior: HitTestBehavior.opaque,
          gestures: {
            ImmediateMultiDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  ImmediateMultiDragGestureRecognizer
                >(ImmediateMultiDragGestureRecognizer.new, (recognizer) {
                  recognizer.onStart = (_) => _CodeBlockDrag(onMove);
                }),
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.code, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<CodeLanguage>(
                    value: model.language,
                    dropdownColor: const Color(0xff21252b),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    iconEnabledColor: Colors.white70,
                    items: [
                      for (final language in CodeLanguage.values)
                        DropdownMenuItem(
                          value: language,
                          child: Text(language.label),
                        ),
                    ],
                    onChanged: (language) {
                      if (language != null) model.language = language;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlockDrag extends Drag {
  _CodeBlockDrag(this.onMove);

  final ValueChanged<Offset> onMove;

  @override
  void update(DragUpdateDetails details) => onMove(details.delta);
}
