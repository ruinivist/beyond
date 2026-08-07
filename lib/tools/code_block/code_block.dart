import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import 'code_language.dart';

class CodeBlockModel extends ChangeNotifier {
  CodeBlockModel(this.size);

  final Size size;
  final controller = CodeLineEditingController(
    options: const CodeLineOptions(indentSize: 2),
  );
  final focusNode = FocusNode();
  CodeLanguage _language = CodeLanguage.dart;

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
    super.dispose();
  }
}

class CodeBlock extends StatelessWidget {
  const CodeBlock({required this.model, super.key});

  final CodeBlockModel model;

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

  final CodeBlockModel model;

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
              child: DropdownButton<CodeLanguage>(
                value: model.language,
                dropdownColor: const Color(0xff21252b),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                iconEnabledColor: Colors.white70,
                items: [
                  for (final language in CodeLanguage.values)
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
