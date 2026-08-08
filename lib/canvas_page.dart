import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:scribble/scribble.dart';

import 'tools/code_block/code_block.dart';
import 'tools/pen/pen_tool.dart';
import 'tools/text/text_block.dart';

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key});

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final _canvasController = LazyCanvasController(
    buildCacheExtent: const Offset(600, 400),
  );
  final _codeBlocks = <CodeBlockModel>[];
  final _textBlocks = <TextBlockModel>[];
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

  Offset _viewportCenter() {
    final viewport = _canvasController.canvasSize;
    return _canvasController.offset +
        Offset(viewport.width, viewport.height) / (2 * _canvasController.scale);
  }

  void _toggleTextPlacement() {
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
    if (!_textPlacementEnabled) return;
    setState(() => _textPlacementEnabled = false);
    _addTextBlock(
      _canvasController.offset + event.localPosition / _canvasController.scale,
    );
  }

  void _addTextBlock(Offset position) {
    const size = Size(280, 52);
    final model = TextBlockModel();

    _textBlocks.add(model);
    _canvasController.addChild(
      position,
      TextBlock(model: model),
      childSize: size,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => model.focusNode.requestFocus(),
    );
  }

  void _addCodeBlock() {
    final scale = _canvasController.scale;
    final viewport = _canvasController.canvasSize;
    final size = Size(
      math.max(
        codeBlockMinimumSize.width,
        math.min(600, (viewport.width - 32) / scale),
      ),
      math.max(
        codeBlockMinimumSize.height,
        math.min(400, (viewport.height - 32) / scale),
      ),
    );
    final model = CodeBlockModel(size);

    _codeBlocks.add(model);
    _canvasController.addChild(
      _viewportCenter() - Offset(size.width / 2, size.height / 2),
      CodeBlock(model: model),
      childSize: size,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => model.focusNode.requestFocus(),
    );
  }

  void _addStroke(Sketch sketch) {
    final stroke = positionSketch(
      sketch,
      canvasOffset: _canvasController.offset,
      canvasScale: _canvasController.scale,
    );
    _canvasController.addChild(
      stroke.position,
      SizedBox.fromSize(
        size: stroke.size,
        child: ScribbleSketch(sketch: stroke.sketch),
      ),
      childSize: stroke.size,
    );
  }

  void _togglePen() {
    setState(() {
      _penEnabled = !_penEnabled;
      _textPlacementEnabled = false;
      _spaceHeld = false;
    });
    if (_penEnabled) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
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
    for (final block in _codeBlocks) {
      block.dispose();
    }
    for (final block in _textBlocks) {
      block.dispose();
    }
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _penTool.dispose();
    _canvasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
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
                              style: _textPlacementEnabled
                                  ? TextButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.secondaryContainer,
                                    )
                                  : null,
                              icon: const Icon(Icons.title),
                              label: const Text('Text'),
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Add code block',
                          child: TextButton.icon(
                            onPressed: _addCodeBlock,
                            icon: const Icon(Icons.code),
                            label: const Text('Code'),
                          ),
                        ),
                        Tooltip(
                          message: 'Draw with pen',
                          child: Semantics(
                            selected: _penEnabled,
                            child: TextButton.icon(
                              onPressed: _togglePen,
                              style: _penEnabled
                                  ? TextButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.secondaryContainer,
                                    )
                                  : null,
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
        ],
      ),
    );
  }
}
