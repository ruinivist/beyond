// Provides editable, resizable, syntax-highlighted code blocks.
// Used by the canvas code tool and element renderer.

import 'dart:math' as math;

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_element_model.dart';
import 'package:beyond/canvas/editor/widgets/pointer_scroll_boundary.dart';
import 'package:beyond/canvas/editor/widgets/resize_handle.dart';
import 'package:beyond/canvas/tools/code/code_language.dart';
import 'package:beyond/ui/common/select.dart';
import 'package:beyond/ui/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:scroll_animator/scroll_animator.dart';

export 'code_language.dart';

part 'code_tool_model.dart';
part 'code_tool_helpers.dart';

// ---------- Rendering ----------

/// Renders an editable code surface with language selection and resizing.
/// Used by the canvas element stack.
class CodeTool extends StatelessWidget {
  const CodeTool({
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
                            backgroundColor: model.selected ? colors.accentSoft : colors.surface,
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
                      ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
                        () => ScaleGestureRecognizer(
                          allowedButtonsFilter: (buttons) => buttons == kPrimaryButton,
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
