// Provides minimal, syntax-highlighted code blocks with inline editing controls.
// Used by the canvas code tool and element renderer.

import 'dart:math' as math;

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_element_model.dart';
import 'package:beyond/canvas/editor/widgets/pointer_scroll_boundary.dart';
import 'package:beyond/canvas/editor/widgets/resize_handle.dart';
import 'package:beyond/canvas/tools/code/code_language.dart';
import 'package:beyond/theme/theme.dart';
import 'package:beyond/ui/common/select.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:scroll_animator/scroll_animator.dart';

export 'code_language.dart';

part 'code_tool_helpers.dart';
part 'code_tool_model.dart';

// ---------- Rendering ----------

/// Renders a movable preview or an editable code surface.
/// Used by the canvas element stack.
class CodeTool extends StatelessWidget {
  const CodeTool({
    required this.model,
    required this.onEdit,
    required this.onMove,
    required this.onChangeBoundary,
    super.key,
  });

  final CodeBlockModel model;
  final VoidCallback onEdit;
  final ValueChanged<Offset> onMove;
  final VoidCallback onChangeBoundary;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final theme = BTheme.of(context);
        final colors = theme.colors;
        final codeStyle = theme.typo.code.copyWith(color: colors.textPrimary);
        final background = model.selected ? colors.accentSoft : colors.surface;
        final editing = model.active;
        final showTitle = editing || model.title.trim().isNotEmpty;
        final bodyTop = showTitle ? _codeTitleHeight : 0.0;
        return Semantics(
          container: true,
          selected: model.selected,
          child: SizedBox.fromSize(
            size: model.size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: bodyTop,
                  child: Material(
                    key: const ValueKey('code-block-surface'),
                    color: background,
                    elevation: theme.geo.elevationLow,
                    shadowColor: colors.shadow,
                    shape: RoundedRectangleBorder(
                      borderRadius: theme.geo.radiusMedium,
                      side: model.selected
                          ? BorderSide(color: colors.accent, width: 2)
                          : BorderSide(color: colors.borderSubtle),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: PointerScrollBoundary(
                            child: CodeEditor(
                              controller: model.controller,
                              scrollController: model.scrollController,
                              focusNode: model.focusNode,
                              autofocus: false,
                              readOnly: !editing,
                              showCursorWhenReadOnly: false,
                              padding: EdgeInsets.fromLTRB(
                                _codeEditorPadding,
                                _codeEditorPadding,
                                editing ? 116 : _codeEditorPadding,
                                _codeEditorPadding,
                              ),
                              style: CodeEditorStyle(
                                fontFamily: codeStyle.fontFamily,
                                fontFamilyFallback: codeStyle.fontFamilyFallback,
                                fontSize: codeStyle.fontSize,
                                fontHeight: codeStyle.height,
                                textColor: colors.textPrimary,
                                backgroundColor: background,
                                cursorColor: colors.accent,
                                selectionColor: colors.accentSubtle,
                                codeTheme: model.language.theme(theme.syntaxTheme),
                              ),
                              indicatorBuilder: model.showLineNumbers
                                  ? (context, controller, chunkController, notifier) => ColoredBox(
                                      key: const ValueKey('code-line-numbers'),
                                      color: colors.surfaceSubtle,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: DefaultCodeLineNumber(
                                          controller: controller,
                                          notifier: notifier,
                                          minNumberCount: 1,
                                          textStyle: codeStyle.copyWith(color: colors.textMuted),
                                          focusedTextStyle: codeStyle.copyWith(color: colors.textSecondary),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        if (editing)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: ResizeHandle(
                              key: const ValueKey('code-block-resize-handle'),
                              semanticLabel: 'Resize code block',
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
                if (showTitle)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _CodeTitleTab(
                      model: model,
                      editing: editing,
                      maxWidth: model.size.width - 124,
                    ),
                  ),
                if (editing)
                  Positioned(
                    right: _codeControlInset,
                    top: bodyTop + _codeControlInset,
                    child: SearchableSelect<CodeLanguage>(
                      key: const ValueKey('code-language-picker'),
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
                  ),
                if (!editing)
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: GestureDetector(
                        key: const ValueKey('code-block-preview-surface'),
                        behavior: HitTestBehavior.opaque,
                        dragStartBehavior: DragStartBehavior.down,
                        onTap: onEdit,
                        onPanUpdate: (details) => onMove(details.delta),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
