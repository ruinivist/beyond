import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/canvas_page.dart';
import 'package:beyond/canvas/tools/pen/pen_tool.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/theme/starless.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

void main() {
  setUp(() => SharedPreferencesAsyncWeb.registerWith(null));

  testWidgets('undo and redo restore and persist canvas operations', (
    tester,
  ) async {
    final store = _DocumentStore(_document());
    await _pumpCanvas(tester, store);

    _stroke(tester).selected = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(find.byType(PenStroke), findsNothing);

    await _shortcut(tester);
    expect(find.byType(PenStroke), findsOneWidget);
    await _waitForSave(tester);
    expect(store.persisted!.elements, hasLength(1));

    await _shortcut(tester, redo: true);
    expect(find.byType(PenStroke), findsNothing);
    await _waitForSave(tester);
    expect(store.persisted!.elements, isEmpty);
  });

  testWidgets('a drag is one step and a new operation clears redo', (
    tester,
  ) async {
    final store = _DocumentStore(_document());
    await _pumpCanvas(tester, store);
    final start = _stroke(tester).data.position;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PenStroke)),
    );
    await gesture.moveBy(const Offset(30, 10));
    await gesture.moveBy(const Offset(40, 20));
    await gesture.moveBy(const Offset(50, 30));
    await gesture.up();
    await tester.pump();
    final moved = _stroke(tester).data.position;
    expect(moved, isNot(start));

    await _shortcut(tester);
    expect(_stroke(tester).data.position, start);
    await _shortcut(tester);
    expect(_stroke(tester).data.position, start);

    _stroke(tester).selected = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    await _shortcut(tester, redo: true);
    expect(find.byType(PenStroke), findsNothing);
  });

  testWidgets('focused editors keep ownership of undo shortcuts', (
    tester,
  ) async {
    await _pumpCanvas(tester, _DocumentStore(_textDocument()));
    final original = tester.widget<TextBlock>(find.byType(TextBlock)).model;

    await tester.tap(find.byKey(const ValueKey('text-markdown-preview')));
    await tester.pump();
    original.controller.text = 'changed';
    await tester.pump();
    await _shortcut(tester);

    expect(
      tester.widget<TextBlock>(find.byType(TextBlock)).model,
      same(original),
    );
  });

  testWidgets('history retains only the latest 50 operations', (tester) async {
    await _pumpCanvas(tester, _DocumentStore(_penDocument(51)));

    for (var index = 0; index < 51; index++) {
      tester
              .widgetList<PenStroke>(find.byType(PenStroke))
              .map((widget) => widget.model)
              .firstWhere((model) => model.data.id == 'pen-$index')
              .selected =
          true;
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
    }
    expect(find.byType(PenStroke), findsNothing);

    for (var index = 0; index < 51; index++) {
      await _shortcut(tester);
    }
    expect(find.byType(PenStroke), findsNWidgets(50));
    expect(
      tester
          .widgetList<PenStroke>(find.byType(PenStroke))
          .map((widget) => widget.model.data.id),
      isNot(contains('pen-0')),
    );
  });
}

Future<void> _pumpCanvas(
  WidgetTester tester,
  CanvasDocumentStore store,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: starlessLightThemeData,
      home: CanvasPage(documentStore: store),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _shortcut(WidgetTester tester, {bool redo = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (redo) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
  if (redo) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<void> _waitForSave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 320));
  await tester.pump();
}

PenStrokeModel _stroke(WidgetTester tester) =>
    tester.widget<PenStroke>(find.byType(PenStroke)).model;

CanvasDocument _document() => _penDocument(1);

CanvasDocument _penDocument(int count) => CanvasDocument(
  background: CanvasBackgroundKind.plain,
  elements: [
    for (var index = 0; index < count; index++)
      PenElementData(
        id: 'pen-$index',
        position: Offset(
          40 + (index % 10) * 60,
          100 + (index ~/ 10) * 60,
        ),
        size: const Size(40, 40),
        hitSlop: 6,
        color: 0xff000000,
        width: 4,
        points: const [
          PenPointData(Offset(4, 4), pressure: 1),
          PenPointData(Offset(36, 36), pressure: 1),
        ],
      ),
  ],
);

CanvasDocument _textDocument() => CanvasDocument(
  background: CanvasBackgroundKind.plain,
  elements: [
    TextElementData(
      id: 'text',
      position: const Offset(200, 240),
      width: 280,
      height: null,
      markdown: 'original',
      style: const TextNodeStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        color: '#201C1A',
      ),
    ),
  ],
);

class _DocumentStore extends CanvasDocumentStore {
  _DocumentStore(this.initial);

  final CanvasDocument initial;
  CanvasDocument? persisted;

  @override
  Future<CanvasDocument?> load() async => initial.copy();

  @override
  Future<void> save(CanvasDocument document) async {
    persisted = document.copy();
  }
}
