import 'dart:math' as math;

import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:scroll_animator/scroll_animator.dart';

const codeBlockMinimumSize = Size(280, 240);

class CodeBlockModel extends ChangeNotifier {
  CodeBlockModel(Size size) : _size = _clampSize(size);

  Size _size;
  bool _selected = false;
  final controller = CodeLineEditingController();
  final focusNode = FocusNode();
  final scrollController = CodeScrollController(
    verticalScroller: AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    ),
    horizontalScroller: AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    ),
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
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final geo = theme.geo;
    final codeStyle = theme.typo.code.copyWith(color: colors.textPrimary);
    return Listener(
      onPointerDown: onSelect,
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) => SizedBox.fromSize(
          size: model.size,
          child: Material(
            key: const ValueKey('code-block-surface'),
            color: colors.surface,
            elevation: model.selected ? geo.elevationHigh : geo.elevationMedium,
            shadowColor: colors.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: geo.radiusLarge,
              side: model.selected
                  ? BorderSide(color: colors.accent, width: 2)
                  : BorderSide(color: colors.borderSubtle),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  children: [
                    _CodeBlockHeader(model: model, onMove: onMove),
                    Divider(height: 1, color: colors.borderSubtle),
                    Expanded(
                      child: CodeEditor(
                        controller: model.controller,
                        scrollController: model.scrollController,
                        focusNode: model.focusNode,
                        padding: const EdgeInsets.all(8),
                        style: CodeEditorStyle(
                          fontFamily: codeStyle.fontFamily,
                          fontFamilyFallback: codeStyle.fontFamilyFallback,
                          fontSize: codeStyle.fontSize,
                          fontHeight: codeStyle.height,
                          textColor: colors.textPrimary,
                          backgroundColor: colors.surface,
                          cursorColor: colors.accent,
                          cursorLineColor: colors.accentSoft,
                          selectionColor: colors.accentSubtle,
                          codeTheme: model.language.theme(theme.syntaxTheme),
                        ),
                        indicatorBuilder:
                            (context, controller, chunkController, notifier) =>
                                ColoredBox(
                                  color: colors.surfaceSubtle,
                                  child: Row(
                                    children: [
                                      DefaultCodeLineNumber(
                                        controller: controller,
                                        notifier: notifier,
                                        textStyle: codeStyle.copyWith(
                                          color: colors.textMuted,
                                        ),
                                        focusedTextStyle: codeStyle.copyWith(
                                          color: colors.accent,
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
    final color = BTheme.of(context).colors.textMuted;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: Semantics(
        button: true,
        label: 'Resize code block',
        child: RawGestureDetector(
          key: const ValueKey('code-block-resize-handle'),
          behavior: HitTestBehavior.opaque,
          gestures: {
            ScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                  () => ScaleGestureRecognizer(
                    allowedButtonsFilter: (buttons) =>
                        buttons == kPrimaryButton,
                  ),
                  (recognizer) {
                    recognizer.onUpdate = (details) {
                      model.size = Size(
                        model.size.width + details.focalPointDelta.dx,
                        model.size.height + details.focalPointDelta.dy,
                      );
                    };
                  },
                ),
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
    final theme = BTheme.of(context);
    final colors = theme.colors;
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
                Icon(Icons.code, size: 18, color: colors.textMuted),
                const SizedBox(width: 8),
                Select<CodeLanguage>(
                  value: model.language,
                  options: [
                    for (final language in CodeLanguage.values)
                      SelectOption(value: language, label: language.label),
                  ],
                  showBorder: false,
                  onChanged: (language) => model.language = language,
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
