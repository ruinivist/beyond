// Provides minimal, syntax-highlighted code blocks with inline editing controls.
// Used by the canvas code tool and element renderer.

import 'dart:math' as math;

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_element_model.dart';
import 'package:beyond/canvas/editor/widgets/pointer_scroll_boundary.dart';
import 'package:beyond/canvas/editor/widgets/resize_handle.dart';
import 'package:beyond/canvas/tools/code/code_language.dart';
import 'package:beyond/theme/theme.dart';
import 'package:beyond/ui/common/b_switch_button.dart';
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
class CodeTool extends StatefulWidget {
  const CodeTool({
    required this.model,
    required this.onEdit,
    required this.onMove,
    required this.onResize,
    required this.onChangeBoundary,
    super.key,
  });

  final CodeBlockModel model;
  final VoidCallback onEdit;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;
  final VoidCallback onChangeBoundary;

  @override
  State<CodeTool> createState() => _CodeToolState();
}

class _CodeToolState extends State<CodeTool> {
  final _portalController = OverlayPortalController();
  int? _previewPointer;
  Offset? _previewPointerStart;
  Offset? _previewPointerPosition;
  double _previewDragSlop = 0;
  bool _previewDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portalController.show();
    });
  }

  void _handlePreviewPointerDown(PointerDownEvent event) {
    if (widget.model.active || event.buttons != kPrimaryButton || _previewPointer != null) return;
    _previewPointer = event.pointer;
    _previewPointerStart = event.position;
    _previewPointerPosition = event.position;
    _previewDragSlop = computePanSlop(
      event.kind,
      MediaQuery.maybeGestureSettingsOf(context),
    );
    _previewDragging = false;
  }

  void _handlePreviewPointerMove(PointerMoveEvent event) {
    if (event.pointer != _previewPointer) return;
    final start = _previewPointerStart!;
    final previous = _previewPointerPosition!;
    if (!_previewDragging) {
      if ((event.position - start).distance <= _previewDragSlop) return;
      _previewDragging = true;
      widget.model.focusNode.unfocus();
      widget.onMove(event.position - start);
    } else {
      widget.onMove(event.position - previous);
    }
    // re_editor still performs text-selection drags while read-only.
    // Collapse that transient selection after every canvas drag update.
    widget.model.controller.cancelSelection();
    _previewPointerPosition = event.position;
  }

  void _handlePreviewPointerUp(PointerUpEvent event) {
    if (event.pointer != _previewPointer) return;
    final dragging = _previewDragging;
    _clearPreviewPointer();
    if (dragging) {
      widget.model
        ..focusNode.unfocus()
        ..controller.cancelSelection();
    } else {
      widget.onEdit();
    }
  }

  void _handlePreviewPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _previewPointer) return;
    _clearPreviewPointer();
    widget.model
      ..focusNode.unfocus()
      ..controller.cancelSelection();
  }

  void _clearPreviewPointer() {
    _previewPointer = null;
    _previewPointerStart = null;
    _previewPointerPosition = null;
    _previewDragging = false;
  }

  Widget _previewInteraction(Widget editor) {
    return Listener(
      key: const ValueKey('code-block-preview-surface'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePreviewPointerDown,
      onPointerMove: _handlePreviewPointerMove,
      onPointerUp: _handlePreviewPointerUp,
      onPointerCancel: _handlePreviewPointerCancel,
      child: editor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) {
        final model = widget.model;
        final theme = BTheme.of(context);
        final colors = theme.colors;
        final codeStyle = theme.typo.code.copyWith(color: colors.textPrimary);
        final background = model.selected ? colors.accentSoft : colors.surface;
        final editing = model.active;
        final showTitle = editing || model.title.trim().isNotEmpty;
        final titleTab = _CodeTitleTab(model: model, editing: editing);
        return Semantics(
          container: true,
          selected: model.selected,
          child: OverlayPortal.overlayChildLayoutBuilder(
            controller: _portalController,
            overlayChildBuilder: (context, layout) => Positioned(
              left: 0,
              top: 0,
              child: Transform(
                transform: layout.childPaintTransform,
                alignment: Alignment.topLeft,
                child: Transform.translate(
                  offset: const Offset(0, -_codeTitleHeight),
                  child: IgnorePointer(
                    ignoring: !showTitle,
                    child: AnimatedSwitcher(
                      duration: model.title.trim().isEmpty ? _codeControlAnimationDuration : Duration.zero,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: _codeControlTransition,
                      child: showTitle
                          ? editing
                                ? titleTab
                                : GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    dragStartBehavior: DragStartBehavior.down,
                                    onTap: widget.onEdit,
                                    onPanUpdate: (details) => widget.onMove(details.delta),
                                    child: titleTab,
                                  )
                          : const SizedBox(key: ValueKey('code-title-hidden')),
                    ),
                  ),
                ),
              ),
            ),
            child: SizedBox.fromSize(
              size: model.size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
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
                            child: _previewInteraction(
                              PointerScrollBoundary(
                                child: CodeEditor(
                                  controller: model.controller,
                                  scrollController: model.scrollController,
                                  focusNode: model.focusNode,
                                  autofocus: false,
                                  readOnly: !editing,
                                  showCursorWhenReadOnly: false,
                                  padding: const EdgeInsets.fromLTRB(
                                    _codeEditorPadding,
                                    _codeEditorPadding,
                                    _codeEditorPadding,
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
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                          ),
                          Positioned(
                            right: _codeControlInset,
                            top: _codeControlInset,
                            child: IgnorePointer(
                              ignoring: !editing,
                              child: AnimatedSwitcher(
                                duration: _codeControlAnimationDuration,
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeOutCubic,
                                transitionBuilder: _codeControlTransition,
                                child: editing
                                    ? SearchableSelect<CodeLanguage>(
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
                                          widget.onChangeBoundary();
                                          model.language = language;
                                          widget.onChangeBoundary();
                                        },
                                      )
                                    : const SizedBox(key: ValueKey('code-language-picker-hidden')),
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
                                      recognizer.onUpdate = (details) => widget.onResize(details.focalPointDelta);
                                    },
                                  ),
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!editing)
                    // re_editor hardcodes a text cursor in its code-field renderer.
                    // Keep inactive blocks on the normal canvas pointer instead.
                    const Positioned.fill(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.basic,
                        opaque: false,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
