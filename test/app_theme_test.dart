import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:plane/main.dart';
import 'package:plane/canvas/tools/code_block/code_language.dart';
import 'package:plane/theme/app_theme.dart';
import 'package:re_editor/re_editor.dart';
import 'package:scribble/scribble.dart';

void main() {
  testWidgets('Starless Light maps onto the current UI', (tester) async {
    final components = starlessLight.components;
    await tester.pumpWidget(const PlaneApp());
    await tester.pump();

    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    final background = canvas.controller.background as DotGridBackground;
    expect(background.backgroundColor, components.canvas.background);
    expect(background.dotColor, components.canvas.grid);
    expect(background.spacing, components.canvas.gridSpacing);
    expect(background.size, components.canvas.dotRadius);

    final toolbar = tester.widget<Material>(
      find.byKey(const ValueKey('toolbar-surface')),
    );
    expect(toolbar.color, components.toolbar.background);
    expect(toolbar.shadowColor, components.toolbar.shadow);

    await tester.tap(find.text('Pen'));
    await tester.pump();
    final penButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Pen'),
    );
    expect(
      penButton.style!.backgroundColor!.resolve({}),
      components.toolbar.selectedBackground,
    );
    final pen = tester.widget<Scribble>(find.byType(Scribble));
    expect(
      (pen.notifier.value as Drawing).selectedColor,
      components.canvas.penStroke.toARGB32(),
    );

    await tester.tap(find.text('Pen'));
    await tester.tap(find.text('Code'));
    await tester.pump();
    final codeSurface = tester.widget<Material>(
      find.byKey(const ValueKey('code-block-surface')),
    );
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(codeSurface.color, components.codeEditor.background);
    expect(editor.style!.cursorColor, components.codeEditor.cursor);
    expect(editor.style!.selectionColor, components.codeEditor.selection);
    expect(editor.style!.fontFamily, starlessLight.typography.mono.fontFamily);
    expect(
      editor.style!.fontFamilyFallback,
      starlessLight.typography.mono.fontFamilyFallback,
    );
    final lineNumbers = tester.widget<DefaultCodeLineNumber>(
      find.byType(DefaultCodeLineNumber),
    );
    expect(
      lineNumbers.textStyle!.fontFamily,
      starlessLight.typography.mono.fontFamily,
    );
    expect(
      lineNumbers.focusedTextStyle!.fontFamily,
      starlessLight.typography.mono.fontFamily,
    );
    expect(
      editor.style!.codeTheme!.theme,
      CodeLanguage.dart.theme(components.codeEditor.syntaxTheme)!.theme,
    );

    await tester.tap(find.text('Markdown'));
    await tester.pump();
    final markdownSurface = tester.widget<Material>(
      find.byKey(const ValueKey('markdown-block-surface')),
    );
    expect(markdownSurface.color, components.block.background);
    expect(find.byKey(const ValueKey('markdown-mode-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    final about = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'About'),
    );
    expect(dialog.backgroundColor, components.settings.background);
    expect(dialog.shadowColor, components.settings.shadow);
    expect(about.selectedTileColor, components.settings.selectedBackground);
    expect(about.selectedColor, components.settings.selectedForeground);
  });

  test('syntax token styles inherit the editor font', () {
    final code = starlessLight.components.codeEditor;

    for (final language in CodeLanguage.values) {
      final theme = language.theme(code.syntaxTheme);
      if (theme == null) continue;

      for (final style in theme.theme.values) {
        expect(style.fontFamily, isNull);
      }
    }
  });
}
