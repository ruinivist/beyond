import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';

import 'tools/code_block/code_block.dart';
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

  Offset _viewportCenter() {
    final viewport = _canvasController.canvasSize;
    return _canvasController.offset +
        Offset(viewport.width, viewport.height) / (2 * _canvasController.scale);
  }

  void _addTextBlock() {
    const size = Size(280, 52);
    final model = TextBlockModel();

    _textBlocks.add(model);
    _canvasController.addChild(
      _viewportCenter() - Offset(size.width / 2, size.height / 2),
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
      math.max(280, math.min(600, (viewport.width - 32) / scale)),
      math.max(240, math.min(400, (viewport.height - 32) / scale)),
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

  @override
  void dispose() {
    for (final block in _codeBlocks) {
      block.dispose();
    }
    for (final block in _textBlocks) {
      block.dispose();
    }
    _canvasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          LazyCanvas(controller: _canvasController),
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
                          message: 'Add text',
                          child: TextButton.icon(
                            onPressed: _addTextBlock,
                            icon: const Icon(Icons.title),
                            label: const Text('Text'),
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
