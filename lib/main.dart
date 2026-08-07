import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

void main() => runApp(const PlaneApp());

class PlaneApp extends StatelessWidget {
  const PlaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
      home: const CanvasPage(),
    );
  }
}

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key});

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final _canvasController = LazyCanvasController();
  final _blocks = <_CodeBlockModel>[];

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
    final model = _CodeBlockModel(size);

    _blocks.add(model);
    _canvasController.addChild(
      center - Offset(size.width / 2, size.height / 2),
      _CodeBlock(model: model),
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

class _CodeBlockModel extends ChangeNotifier {
  _CodeBlockModel(this.size);

  final Size size;
  final controller = CodeLineEditingController(
    options: const CodeLineOptions(indentSize: 2),
  );
  final focusNode = FocusNode();
  _CodeLanguage _language = _CodeLanguage.dart;

  _CodeLanguage get language => _language;

  set language(_CodeLanguage value) {
    if (_language == value) return;
    _language = value;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.model});

  final _CodeBlockModel model;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: model.size,
      child: Material(
        color: const Color(0xff282c34),
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(10),
        child: ListenableBuilder(
          listenable: model,
          builder: (context, _) => Column(
            children: [
              _CodeBlockHeader(model: model),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: CodeEditor(
                  controller: model.controller,
                  focusNode: model.focusNode,
                  wordWrap: false,
                  autocompleteSymbols: true,
                  padding: const EdgeInsets.all(8),
                  style: CodeEditorStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontHeight: 1.4,
                    textColor: const Color(0xffabb2bf),
                    backgroundColor: const Color(0xff282c34),
                    cursorLineColor: Colors.white.withValues(alpha: 0.04),
                    codeTheme: model.language.theme,
                  ),
                  indicatorBuilder:
                      (context, controller, chunkController, notifier) => Row(
                        children: [
                          DefaultCodeLineNumber(
                            controller: controller,
                            notifier: notifier,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeBlockHeader extends StatelessWidget {
  const _CodeBlockHeader({required this.model});

  final _CodeBlockModel model;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.code, size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<_CodeLanguage>(
                value: model.language,
                dropdownColor: const Color(0xff21252b),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                iconEnabledColor: Colors.white70,
                items: [
                  for (final language in _CodeLanguage.values)
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
    );
  }
}

enum _CodeLanguage {
  dart('Dart'),
  javascript('JavaScript'),
  typescript('TypeScript'),
  python('Python'),
  go('Go'),
  rust('Rust'),
  plainText('Plain text');

  const _CodeLanguage(this.label);

  final String label;

  Mode? get mode => switch (this) {
    dart => langDart,
    javascript => langJavascript,
    typescript => langTypescript,
    python => langPython,
    go => langGo,
    rust => langRust,
    plainText => null,
  };

  CodeHighlightTheme? get theme => mode == null
      ? null
      : CodeHighlightTheme(
          languages: {name: CodeHighlightThemeMode(mode: mode!)},
          theme: atomOneDarkTheme,
        );
}
