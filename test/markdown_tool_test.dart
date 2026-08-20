import 'dart:convert';

import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/canvas/tools/text/text_node.dart';
import 'package:beyond/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

void main() {
  setUp(() async {
    SharedPreferencesAsyncWeb.registerWith(null);
    await SharedPreferencesAsync().remove(CanvasDocumentStore.key);
  });

  testWidgets('stored Markdown documents load, render, and remain editable', (
    tester,
  ) async {
    const source = '# Stored Markdown\n\n**exact source**';
    final document = CanvasDocument(
      nodes: [
        TextNodeData(
          id: 'stored-markdown',
          position: const Offset(120, 200),
          width: 320,
          markdown: source,
          style: const TextNodeStyle(
            fontFamily: 'Source Serif 4',
            fontSize: 20,
            color: '#201C1A',
          ),
        ),
      ],
    );
    await SharedPreferencesAsync().setString(
      CanvasDocumentStore.key,
      jsonEncode(document.toJson()),
    );

    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    final block = find.byType(TextBlock);
    final model = tester.widget<TextBlock>(block).model;
    final preview = tester.widget<MarkdownBody>(
      find.byKey(const ValueKey('text-markdown-preview')),
    );
    expect(model.node.markdown, source);
    expect(preview.data, source);

    await tester.tap(
      find.byKey(const ValueKey('text-markdown-preview-surface')),
    );
    await tester.pump();
    expect(model.controller.text, source);
    expect(find.byKey(const ValueKey('text-markdown-editor')), findsOneWidget);

    const edited = '$source\n\nEdited';
    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      edited,
    );
    await tester.pump();
    expect(model.node.markdown, edited);
  });
}
