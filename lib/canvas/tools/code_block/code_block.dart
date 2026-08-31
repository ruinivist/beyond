import 'dart:math' as math;

import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_element_model.dart';
import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:beyond/foundation/pointer_scroll_boundary.dart';
import 'package:beyond/foundation/resize_handle.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:scroll_animator/scroll_animator.dart';

class CodeBlockModel extends CanvasElementModel<CodeElementData> {
  CodeBlockModel(CodeElementData data) : super(data) {
    controller.text = data.source;
    controller.addListener(_syncSource);
  }

  final controller = CodeLineEditingController(
    options: const CodeLineOptions(indentSize: 4),
  );
  final focusNode = FocusNode();
  final scrollController = CodeScrollController(
    verticalScroller: AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    ),
    horizontalScroller: AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    ),
  );
  @override
  Offset get canvasPosition => data.position;

  @override
  Size get canvasSize => data.size;

  Size get size => data.size;

  set size(Size value) {
    final nextSize = _clampSize(value);
    if (data.size == nextSize) return;
    data.size = nextSize;
    notifyListeners();
  }

  CodeLanguage get language => data.language;

  set language(CodeLanguage value) {
    if (data.language == value) return;
    data.language = value;
    notifyListeners();
  }

  @override
  void moveBy(Offset delta) {
    if (delta == Offset.zero) return;
    data.position += delta;
    notifyListeners();
  }

  void _syncSource() {
    if (data.source == controller.text) return;
    data.source = controller.text;
    notifyListeners();
  }

  @override
  void dispose() {
    controller
      ..removeListener(_syncSource)
      ..dispose();
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
    required this.onMove,
    required this.onChangeBoundary,
    super.key,
  });

  final CodeBlockModel model;
  final ValueChanged<Offset> onMove;
  final VoidCallback onChangeBoundary;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final geo = theme.geo;
    final codeStyle = theme.typo.code.copyWith(color: colors.textPrimary);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => Semantics(
        container: true,
        selected: model.selected,
        child: SizedBox.fromSize(
          size: model.size,
          child: Material(
            key: const ValueKey('code-block-surface'),
            color: model.selected ? colors.accentSoft : colors.surface,
            elevation: geo.elevationMedium,
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
                    _CodeBlockHeader(
                      model: model,
                      onMove: onMove,
                      onChangeBoundary: onChangeBoundary,
                    ),
                    Divider(height: 1, color: colors.borderSubtle),
                    Expanded(
                      child: PointerScrollBoundary(
                        child: CodeEditor(
                          controller: model.controller,
                          scrollController: model.scrollController,
                          focusNode: model.focusNode,
                          autofocus: false,
                          padding: const EdgeInsets.all(8),
                          style: CodeEditorStyle(
                            fontFamily: codeStyle.fontFamily,
                            fontFamilyFallback: codeStyle.fontFamilyFallback,
                            fontSize: codeStyle.fontSize,
                            fontHeight: codeStyle.height,
                            textColor: colors.textPrimary,
                            backgroundColor: model.selected
                                ? colors.accentSoft
                                : colors.surface,
                            cursorColor: colors.accent,
                            selectionColor: colors.accentSubtle,
                            codeTheme: model.language.theme(
                              theme.syntaxTheme,
                            ),
                          ),
                          indicatorBuilder:
                              (
                                context,
                                controller,
                                chunkController,
                                notifier,
                              ) => ColoredBox(
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
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: ResizeHandle(
                    key: const ValueKey('code-block-resize-handle'),
                    semanticLabel: 'Resize code block',
                    background: false,
                    gestures: {
                      ScaleGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            ScaleGestureRecognizer
                          >(
                            () => ScaleGestureRecognizer(
                              allowedButtonsFilter: (buttons) =>
                                  buttons == kPrimaryButton,
                            ),
                            (recognizer) {
                              recognizer.onUpdate = (details) {
                                model.size = Size(
                                  model.size.width + details.focalPointDelta.dx,
                                  model.size.height +
                                      details.focalPointDelta.dy,
                                );
                              };
                            },
                          ),
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

class _CodeBlockHeader extends StatelessWidget {
  const _CodeBlockHeader({
    required this.model,
    required this.onMove,
    required this.onChangeBoundary,
  });

  final CodeBlockModel model;
  final ValueChanged<Offset> onMove;
  final VoidCallback onChangeBoundary;

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
                SearchableSelect<CodeLanguage>(
                  value: model.language,
                  preferredValues: CodeLanguage.values,
                  searchHint: 'Search languages…',
                  options: [
                    for (final language in CodeLanguage.values)
                      SelectOption(value: language, label: language.label),
                  ],
                  showBorder: false,
                  onChanged: (language) {
                    onChangeBoundary();
                    model.language = language;
                    onChangeBoundary();
                  },
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
