import 'dart:async';
import 'dart:math' as math;

import 'package:beyond/canvas/tools/code_block/code_block.dart';
import 'package:beyond/canvas/tools/markdown/markdown_block.dart';
import 'package:beyond/canvas/tools/pen/pen_tool.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/canvas/tools/text/text_node.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/widgets/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:scribble/scribble.dart';

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key});

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final _canvasController = LazyCanvasController(
    buildCacheExtent: const Offset(600, 400),
  );
  final _codeBlocks = <CodeBlockModel, ({String id, Offset position})>{};
  final _markdownBlocks =
      <MarkdownBlockModel, ({String id, Offset position})>{};
  final _textBlocks = <TextBlockModel, String>{};
  TextBlockModel? _selectedTextBlock;
  final _strokeIds = <String>[];
  final _interactiveBlockPointerIds = <int>{};
  late final PenTool _penTool;
  var _penEnabled = false;
  var _textPlacementEnabled = false;
  var _spaceHeld = false;

  @override
  void initState() {
    super.initState();
    _penTool = PenTool(onStroke: _addStroke);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colors = BTheme.of(context).colors;
    _canvasController.background = DotGridBackground(
      dotColor: colors.canvasGrid,
      backgroundColor: colors.canvasBackground,
    );
    _penTool.setColor(colors.accent);
  }

  Offset _viewportCenter() {
    final viewport = _canvasController.canvasSize;
    return _canvasController.offset +
        Offset(viewport.width, viewport.height) / (2 * _canvasController.scale);
  }

  void _toggleTextPlacement() {
    if (!_textPlacementEnabled) _clearBlockSelection();
    setState(() {
      _textPlacementEnabled = !_textPlacementEnabled;
      _penEnabled = false;
      _spaceHeld = false;
    });
    if (_textPlacementEnabled) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _handleCanvasPointerDown(PointerDownEvent event) {
    final onInteractiveBlock = _interactiveBlockPointerIds.remove(
      event.pointer,
    );
    if (_textPlacementEnabled) {
      setState(() => _textPlacementEnabled = false);
      _addTextBlock(
        _canvasController.offset +
            event.localPosition / _canvasController.scale,
      );
      return;
    }
    if (onInteractiveBlock) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _clearBlockSelection();
  }

  void _handleCodeBlockPointerDown(
    CodeBlockModel model,
    PointerDownEvent event,
  ) {
    _interactiveBlockPointerIds.add(event.pointer);
    if (_textPlacementEnabled || _penEnabled) return;
    final entry = _codeBlocks[model];
    if (entry == null) return;
    _bringBlockToFront(entry.id);
    _selectCodeBlock(model);
  }

  void _handleMarkdownBlockPointerDown(
    MarkdownBlockModel model,
    PointerDownEvent event,
  ) {
    _interactiveBlockPointerIds.add(event.pointer);
    if (_textPlacementEnabled || _penEnabled) return;
    final entry = _markdownBlocks[model];
    if (entry == null) return;
    _bringBlockToFront(entry.id);
    _selectMarkdownBlock(model);
  }

  void _handleTextBlockPointerDown(
    TextBlockModel model,
    PointerDownEvent event,
  ) {
    _interactiveBlockPointerIds.add(event.pointer);
    if (_textPlacementEnabled || _penEnabled) return;
    final canvasId = _textBlocks.remove(model);
    if (canvasId == null) return;
    _textBlocks[model] = canvasId;
    _bringBlockToFront(canvasId);
    _selectTextBlock(model);
  }

  void _bringBlockToFront(String id) {
    _canvasController.bringToFront(id);
    _bringStrokesToFront();
  }

  void _bringStrokesToFront() {
    // ponytail: linear in stroke count; add canvas layers if profiling
    // demands it.
    _strokeIds.forEach(_canvasController.bringToFront);
  }

  void _selectCodeBlock(CodeBlockModel selected) {
    setState(() {
      _selectedTextBlock = null;
      for (final model in _textBlocks.keys) {
        model.selected = false;
      }
      for (final model in _codeBlocks.keys) {
        model.selected = model == selected;
      }
      for (final model in _markdownBlocks.keys) {
        model.selected = false;
      }
    });
  }

  void _selectMarkdownBlock(MarkdownBlockModel selected) {
    setState(() {
      _selectedTextBlock = null;
      for (final model in _textBlocks.keys) {
        model.selected = false;
      }
      for (final model in _codeBlocks.keys) {
        model.selected = false;
      }
      for (final model in _markdownBlocks.keys) {
        model.selected = model == selected;
      }
    });
  }

  void _selectTextBlock(TextBlockModel selected) {
    setState(() {
      _selectedTextBlock = selected;
      for (final model in _textBlocks.keys) {
        model.selected = identical(model, selected);
      }
      for (final model in _codeBlocks.keys) {
        model.selected = false;
      }
      for (final model in _markdownBlocks.keys) {
        model.selected = false;
      }
    });
  }

  void _clearBlockSelection() {
    setState(() {
      _selectedTextBlock = null;
      for (final model in _textBlocks.keys) {
        model.selected = false;
      }
      for (final model in _codeBlocks.keys) {
        model.selected = false;
      }
      for (final model in _markdownBlocks.keys) {
        model.selected = false;
      }
    });
  }

  void _changeTextStyle(TextBlockModel model, TextNodeStyle style) {
    model.style = style;
  }

  void _moveCodeBlock(CodeBlockModel model, Offset screenDelta) {
    if (_textPlacementEnabled || _penEnabled) return;
    final entry = _codeBlocks[model];
    if (entry == null) return;

    final position = entry.position + screenDelta / _canvasController.scale;
    _codeBlocks[model] = (id: entry.id, position: position);
    _canvasController.updatePosition(entry.id, position);
  }

  void _moveTextBlock(TextBlockModel model, Offset screenDelta) {
    if (_textPlacementEnabled || _penEnabled) return;
    final canvasId = _textBlocks[model];
    if (canvasId == null) return;

    model.node.position += screenDelta / _canvasController.scale;
    _canvasController.updatePosition(canvasId, model.node.position);
  }

  void _moveMarkdownBlock(MarkdownBlockModel model, Offset screenDelta) {
    if (_textPlacementEnabled || _penEnabled) return;
    final entry = _markdownBlocks[model];
    if (entry == null) return;

    final position = entry.position + screenDelta / _canvasController.scale;
    _markdownBlocks[model] = (id: entry.id, position: position);
    _canvasController.updatePosition(entry.id, position);
  }

  void _addTextBlock(Offset position) {
    final node = TextNodeData(
      id: _newTextNodeId(),
      position: position,
      width: textNodeDefaultWidth,
      markdown: '',
      style: const TextNodeStyle(
        fontFamily: 'Source Serif 4',
        fontSize: textNodeDefaultFontSize,
        color: '#201C1A',
      ),
    );
    final model = TextBlockModel(node);

    final id = _canvasController.addChild(
      node.position,
      TextBlock(
        model: model,
        onSelect: (event) => _handleTextBlockPointerDown(model, event),
        onMove: (delta) => _moveTextBlock(model, delta),
      ),
      childSize: Size(node.width, 52),
    );
    _textBlocks[model] = id;
    _selectTextBlock(model);
    _bringStrokesToFront();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => model.focusNode.requestFocus(),
    );
  }

  // ponytail: local timestamp IDs; use UUIDs when documents can merge.
  String _newTextNodeId() =>
      'text-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  void _addCodeBlock() {
    _prepareInteractiveBlock();
    final size = _fittedBlockSize(const Size(600, 400), codeBlockMinimumSize);
    final model = CodeBlockModel(size);
    final position =
        _viewportCenter() - Offset(size.width / 2, size.height / 2);

    final id = _canvasController.addChild(
      position,
      CodeBlock(
        model: model,
        onSelect: (event) => _handleCodeBlockPointerDown(model, event),
        onMove: (delta) => _moveCodeBlock(model, delta),
      ),
      childSize: size,
    );
    _codeBlocks[model] = (id: id, position: position);
    _bringStrokesToFront();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => model.focusNode.requestFocus(),
    );
  }

  void _addMarkdownBlock() {
    _prepareInteractiveBlock();
    final size = _fittedBlockSize(
      const Size(560, 420),
      markdownBlockMinimumSize,
    );
    final model = MarkdownBlockModel(size);
    final position =
        _viewportCenter() - Offset(size.width / 2, size.height / 2);

    final id = _canvasController.addChild(
      position,
      MarkdownBlock(
        model: model,
        onSelect: (event) => _handleMarkdownBlockPointerDown(model, event),
        onMove: (delta) => _moveMarkdownBlock(model, delta),
      ),
      childSize: size,
    );
    _markdownBlocks[model] = (id: id, position: position);
    _bringStrokesToFront();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => model.focusNode.requestFocus(),
    );
  }

  Size _fittedBlockSize(Size preferred, Size minimum) {
    final scale = _canvasController.scale;
    final viewport = _canvasController.canvasSize;
    return Size(
      math.max(
        minimum.width,
        math.min(preferred.width, (viewport.width - 32) / scale),
      ),
      math.max(
        minimum.height,
        math.min(preferred.height, (viewport.height - 32) / scale),
      ),
    );
  }

  void _prepareInteractiveBlock() {
    _clearBlockSelection();
    setState(() {
      _penEnabled = false;
      _textPlacementEnabled = false;
      _spaceHeld = false;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _addStroke(Sketch sketch) {
    final stroke = positionSketch(
      sketch,
      canvasOffset: _canvasController.offset,
      canvasScale: _canvasController.scale,
    );
    _strokeIds.add(
      _canvasController.addChild(
        stroke.position,
        SizedBox.fromSize(
          size: stroke.size,
          child: ScribbleSketch(sketch: stroke.sketch),
        ),
        childSize: stroke.size,
      ),
    );
  }

  void _togglePen() {
    if (!_penEnabled) _clearBlockSelection();
    setState(() {
      _penEnabled = !_penEnabled;
      _textPlacementEnabled = false;
      _spaceHeld = false;
    });
    if (_penEnabled) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _showSettingsDialog() {
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: BTheme.of(context).colors.scrim,
        builder: (_) => const SettingsDialog(),
      ),
    );
  }

  bool _handleKeyEvent(KeyEvent event) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final editingText =
        focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (!_penEnabled ||
        editingText ||
        event.logicalKey != LogicalKeyboardKey.space) {
      return false;
    }
    final held = event is! KeyUpEvent;
    if (_spaceHeld != held) setState(() => _spaceHeld = held);
    return true;
  }

  @override
  void dispose() {
    for (final block in _codeBlocks.keys) {
      block.dispose();
    }
    for (final block in _markdownBlocks.keys) {
      block.dispose();
    }
    for (final block in _textBlocks.keys) {
      block.dispose();
    }
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _penTool.dispose();
    _canvasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final geo = theme.geo;
    return Scaffold(
      body: Stack(
        children: [
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _handleCanvasPointerDown,
            child: LazyCanvas(controller: _canvasController),
          ),
          if (_penEnabled)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _spaceHeld,
                child: Scribble(notifier: _penTool),
              ),
            ),
          if (_selectedTextBlock case final selected?)
            CompositedTransformFollower(
              link: selected.layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topCenter,
              followerAnchor: Alignment.bottomCenter,
              offset: const Offset(0, -8),
              child: TextStylePopover(
                model: selected,
                onStyleChanged: (style) => _changeTextStyle(selected, style),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Material(
                  key: const ValueKey('toolbar-surface'),
                  color: colors.surfaceRaised,
                  elevation: geo.elevationLow,
                  shadowColor: colors.shadow,
                  shape: RoundedRectangleBorder(
                    borderRadius: geo.radiusMedium,
                    side: BorderSide(color: colors.borderSubtle),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Place text',
                          child: Semantics(
                            selected: _textPlacementEnabled,
                            child: TextButton.icon(
                              onPressed: _toggleTextPlacement,
                              style: _toolbarButtonStyle(
                                colors,
                                geo,
                                selected: _textPlacementEnabled,
                              ),
                              icon: const Icon(Icons.title),
                              label: const Text('Text'),
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Add code block',
                          child: TextButton.icon(
                            onPressed: _addCodeBlock,
                            style: _toolbarButtonStyle(colors, geo),
                            icon: const Icon(Icons.code),
                            label: const Text('Code'),
                          ),
                        ),
                        Tooltip(
                          message: 'Add markdown block',
                          child: TextButton.icon(
                            onPressed: _addMarkdownBlock,
                            style: _toolbarButtonStyle(colors, geo),
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Markdown'),
                          ),
                        ),
                        Tooltip(
                          message: 'Draw with pen',
                          child: Semantics(
                            selected: _penEnabled,
                            child: TextButton.icon(
                              onPressed: _togglePen,
                              style: _toolbarButtonStyle(
                                colors,
                                geo,
                                selected: _penEnabled,
                              ),
                              icon: const Icon(Icons.draw),
                              label: const Text('Pen'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  key: const ValueKey('settings-button-surface'),
                  color: colors.surfaceRaised,
                  elevation: geo.elevationLow,
                  shadowColor: colors.shadow,
                  shape: RoundedRectangleBorder(
                    borderRadius: geo.radiusMedium,
                    side: BorderSide(color: colors.borderSubtle),
                  ),
                  child: IconButton(
                    key: const ValueKey('settings-button'),
                    tooltip: 'Settings',
                    onPressed: _showSettingsDialog,
                    style: _toolbarIconButtonStyle(colors, geo),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _toolbarButtonStyle(
  BColors colors,
  BGeo geo, {
  bool selected = false,
}) {
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (!selected) return colors.textSecondary;
      if (states.contains(WidgetState.pressed)) {
        return colors.accentPressed;
      }
      if (states.contains(WidgetState.hovered)) {
        return colors.accentHover;
      }
      return colors.accent;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return colors.surfacePressed;
      }
      if (states.contains(WidgetState.hovered)) return colors.surfaceHover;
      return selected ? colors.accentSoft : Colors.transparent;
    }),
    side: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: colors.focusRing)
          : BorderSide.none,
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: geo.radiusSmall),
    ),
  );
}

ButtonStyle _toolbarIconButtonStyle(BColors colors, BGeo geo) {
  return _toolbarButtonStyle(
    colors,
    geo,
  ).copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.all(8)));
}
