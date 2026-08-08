import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../../../theme/app_theme.dart';
import '../../smooth_scroll_controller.dart';
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
  final scrollController = CodeScrollController(
    verticalScroller: SmoothScrollController(),
    horizontalScroller: SmoothScrollController(),
  );
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
    scrollController
      ..verticalScroller.dispose()
      ..horizontalScroller.dispose()
      ..dispose();
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
    final theme = context.appTheme.components;
    final block = theme.block;
    final code = theme.codeEditor;
    return Listener(
      onPointerDown: onSelect,
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) => SizedBox.fromSize(
          size: model.size,
          child: Material(
            key: const ValueKey('code-block-surface'),
            color: code.background,
            elevation: model.selected
                ? block.selectedElevation
                : block.elevation,
            shadowColor: block.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(block.radius),
              side: model.selected
                  ? BorderSide(color: block.selectedBorder, width: 2)
                  : BorderSide(color: block.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  children: [
                    _CodeBlockHeader(model: model, onMove: onMove),
                    Divider(height: 1, color: code.divider),
                    Expanded(
                      child: CodeEditor(
                        controller: model.controller,
                        scrollController: model.scrollController,
                        focusNode: model.focusNode,
                        wordWrap: false,
                        autocompleteSymbols: true,
                        padding: const EdgeInsets.all(8),
                        style: CodeEditorStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontHeight: 1.4,
                          textColor: code.foreground,
                          backgroundColor: code.background,
                          cursorColor: code.cursor,
                          cursorLineColor: code.cursorLine,
                          selectionColor: code.selection,
                          codeTheme: model.language.theme(code.syntaxTheme),
                        ),
                        indicatorBuilder:
                            (context, controller, chunkController, notifier) =>
                                ColoredBox(
                                  color: code.gutterBackground,
                                  child: Row(
                                    children: [
                                      DefaultCodeLineNumber(
                                        controller: controller,
                                        notifier: notifier,
                                        textStyle: TextStyle(
                                          color: code.mutedForeground,
                                        ),
                                        focusedTextStyle: TextStyle(
                                          color: code.cursor,
                                        ),
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
    final color = context.appTheme.components.codeEditor.mutedForeground;
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
          child: SizedBox(
            width: 28,
            height: 28,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.open_in_full, size: 16, color: color),
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
    final code = context.appTheme.components.codeEditor;
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
                Icon(Icons.code, size: 18, color: code.mutedForeground),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<CodeLanguage>(
                    value: model.language,
                    dropdownColor: code.dropdownBackground,
                    style: TextStyle(color: code.foreground, fontSize: 13),
                    iconEnabledColor: code.mutedForeground,
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
