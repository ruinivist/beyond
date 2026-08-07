import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';

import 'tools/code_block/code_block.dart';

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key});

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final _canvasController = LazyCanvasController(
    buildCacheExtent: const Offset(600, 400),
  );
  final _blocks = <CodeBlockModel>[];

  void _addCodeBlock() {
    final scale = _canvasController.scale;
    final viewport = _canvasController.canvasSize;
    final size = Size(
      math.max(280, math.min(600, (viewport.width - 32) / scale)),
      math.max(240, math.min(400, (viewport.height - 32) / scale)),
    );
    final center =
        _canvasController.offset +
        Offset(viewport.width, viewport.height) / (2 * scale);
    final model = CodeBlockModel(size);

    _blocks.add(model);
    _canvasController.addChild(
      center - Offset(size.width / 2, size.height / 2),
      CodeBlock(model: model),
      childSize: size,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => model.focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    for (final block in _blocks) {
      block.dispose();
    }
    _canvasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LazyCanvas(controller: _canvasController),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add code block',
        onPressed: _addCodeBlock,
        child: const Icon(Icons.code),
      ),
    );
  }
}
