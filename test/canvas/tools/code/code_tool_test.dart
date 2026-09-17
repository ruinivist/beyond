// Verifies inactive code blocks distinguish caret clicks from movement drags.
// Exercises CodeTool directly without the canvas persistence boundary.

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/tools/code/code_tool.dart';
import 'package:beyond/theme/starless.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  test('separates presentation and document changes', () {
    final model = _codeModel();
    addTearDown(model.dispose);
    var rebuilds = 0;
    var documentChanges = 0;
    model.addListener(() => rebuilds++);
    model.documentChanges.addListener(() => documentChanges++);

    model
      ..selected = true
      ..active = true;
    expect((rebuilds, documentChanges), (2, 0));

    rebuilds = 0;
    model.controller.text = 'void main() {}';
    expect((rebuilds, documentChanges), (0, 1));

    model.language = CodeLanguage.python;
    expect((rebuilds, documentChanges), (1, 2));
  });

  testWidgets('inactive code distinguishes editing clicks from drags', (
    tester,
  ) async {
    final model = _codeModel(source: 'first line\nsecond line');
    addTearDown(model.dispose);
    var movement = Offset.zero;
    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: CodeTool(
              model: model,
              onEdit: () {
                model.active = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!model.active) return;
                  model.focusNode.unfocus();
                  FocusManager.instance.applyFocusChangesIfNeeded();
                  model.focusNode.requestFocus();
                });
              },
              onMove: (delta) => movement += delta,
              onResize: (_) {},
              onChangeBoundary: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    model.controller.selection = const CodeLineSelection.collapsed(
      index: 1,
      offset: 11,
    );

    final surface = tester.getRect(
      find.byKey(const ValueKey('code-block-surface')),
    );
    await tester.tapAt(surface.topLeft + const Offset(40, 20));
    await tester.pump();
    await tester.pump();

    expect(model.active, isTrue);
    expect(model.focusNode.hasFocus, isTrue);
    expect(
      model.controller.selection,
      const CodeLineSelection.collapsed(index: 0, offset: 2),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: surface.center);
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.text,
    );

    model
      ..active = false
      ..focusNode.unfocus();
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.basic,
    );
    await mouse.removePointer();

    const delta = Offset(80, 60);
    final drag = await tester.startGesture(
      surface.topLeft + const Offset(40, 20),
      kind: PointerDeviceKind.mouse,
    );
    await drag.moveBy(delta / 2);
    await tester.pump();
    expect(model.controller.selection.isCollapsed, isTrue);
    await drag.moveBy(delta / 2);
    await tester.pump();
    expect(model.controller.selection.isCollapsed, isTrue);
    await drag.up();
    await tester.pump();

    expect(movement, delta);
    expect(model.active, isFalse);
    expect(model.focusNode.hasFocus, isFalse);
    await tester.pump(const Duration(milliseconds: 600));
  });
}

CodeBlockModel _codeModel({String source = ''}) => CodeBlockModel(
  CodeElementData(
    id: 'code',
    position: Offset.zero,
    size: const Size(280, 240),
    language: CodeLanguage.dart,
    source: source,
    title: '',
    showLineNumbers: false,
  ),
);
