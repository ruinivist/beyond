// Verifies touch ownership between canvas tools, object edits, and navigation.
// Exercises Plane's handoff through real pointer sequences and persisted models.

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_background.dart';
import 'package:beyond/canvas/tools/arrow/arrow_tool.dart';
import 'package:beyond/canvas/tools/code/code_tool.dart';
import 'package:beyond/canvas/tools/media/media_tool.dart';
import 'package:beyond/canvas/tools/pen/pen_tool.dart';
import 'package:beyond/canvas/tools/shape/shape_tool.dart';
import 'package:beyond/canvas/tools/text/text_tool.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

import '../test_helpers.dart';

// ---------- Tests ----------

void main() {
  setUp(() => SharedPreferencesAsyncWeb.registerWith(null));

  for (final (tool, type) in [('draw', PenStroke), ('arrow', Arrow), ('shape', Shape)]) {
    testWidgets('$tool draws with one finger and discards on navigation takeover', (tester) async {
      await pumpCanvas(tester, TestCanvasDocumentStore(_document()));
      await _chooseTool(tester, tool);
      final controller = _canvas(tester);
      final first = await tester.startGesture(const Offset(200, 300), pointer: 1);
      await first.moveBy(const Offset(60, 30));
      expect(controller.offset, Offset.zero);
      expect(controller.scale, 1);
      final second = await tester.startGesture(const Offset(500, 300), pointer: 2);
      await second.moveBy(const Offset(80, 30));
      expect(controller.scale, greaterThan(1));
      expect(controller.offset, isNot(Offset.zero));
      await second.up();
      final frozen = (controller.offset, controller.scale);
      await first.moveBy(const Offset(60, 30));
      expect((controller.offset, controller.scale), frozen);
      await first.up();
      await tester.pump();
      expect(find.byType(type), findsNothing);

      await tester.dragFrom(const Offset(200, 300), const Offset(120, 90));
      await tester.pump();
      expect(find.byType(type), findsOneWidget);
    });
  }

  for (final (tool, type) in [('text', TextTool), ('code', CodeTool), ('media', MediaTool)]) {
    testWidgets('$tool touch placement waits for release and cancels for pinch', (tester) async {
      await pumpCanvas(tester, TestCanvasDocumentStore(_document()));
      await _chooseTool(tester, tool);
      final first = await tester.startGesture(const Offset(200, 300), pointer: 1);
      expect(find.byType(type), findsNothing);
      final second = await tester.startGesture(const Offset(500, 300), pointer: 2);
      await second.moveBy(const Offset(50, 20));
      await second.up();
      await first.up();
      await tester.pump();
      expect(find.byType(type), findsNothing);

      final drag = await tester.startGesture(const Offset(200, 300));
      await drag.moveBy(const Offset(60, 30));
      await drag.up();
      await tester.pump();
      expect(find.byType(type), findsNothing);
      final canceled = await tester.startGesture(const Offset(200, 300));
      await canceled.cancel();
      await tester.pump();
      expect(find.byType(type), findsNothing);
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      expect(find.byType(type), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 150));
    });
  }

  testWidgets('two actual fingers discard a stylus stroke until interrupted pointers release', (tester) async {
    await pumpCanvas(tester, TestCanvasDocumentStore(_document()));
    await _chooseTool(tester, 'draw');
    final controller = _canvas(tester);
    final stylus = await tester.startGesture(const Offset(200, 300), pointer: 1, kind: PointerDeviceKind.stylus);
    final finger = await tester.startGesture(const Offset(400, 300), pointer: 2);
    await stylus.moveBy(const Offset(40, 20));
    await finger.moveBy(const Offset(20, 0));
    expect((controller.offset, controller.scale), (Offset.zero, 1));
    final second = await tester.startGesture(const Offset(600, 300), pointer: 3);
    await second.moveBy(const Offset(40, 20));
    expect(controller.scale, greaterThan(1));
    await second.up();
    await finger.cancel();
    await stylus.moveBy(const Offset(30, 20));
    await stylus.up();
    await tester.pump();
    expect(find.byType(PenStroke), findsNothing);
    final canceled = await tester.startGesture(const Offset(200, 300));
    await canceled.moveBy(const Offset(50, 20));
    await canceled.cancel();
    await tester.pump();
    expect(find.byType(PenStroke), findsNothing);
    await tester.dragFrom(const Offset(200, 300), const Offset(120, 90));
    await tester.pump();
    expect(find.byType(PenStroke), findsOneWidget);
  });

  testWidgets('group movement stops on takeover and remains one undo step', (tester) async {
    await pumpCanvas(tester, TestCanvasDocumentStore(_document([_pen('a'), _pen('b', const Offset(350, 250))])));
    final models = tester.widgetList<PenStroke>(find.byType(PenStroke)).map((stroke) => stroke.model).toList();
    for (final model in models) {
      model.selected = true;
    }
    final before = models.map((model) => model.data.position).toList();
    final first = await tester.startGesture(const Offset(150, 300), pointer: 1);
    await first.moveBy(const Offset(50, 30));
    await first.moveBy(const Offset(30, 20));
    final moved = models.map((model) => model.data.position).toList();
    expect(moved, isNot(before));
    final second = await tester.startGesture(const Offset(550, 400), pointer: 2);
    await first.moveBy(const Offset(30, 20));
    await second.moveBy(const Offset(30, 20));
    expect(models.map((model) => model.data.position).toList(), moved);
    await second.up();
    await first.up();
    await _undo(tester);
    expect(tester.widgetList<PenStroke>(find.byType(PenStroke)).map((stroke) => stroke.model.data.position), before);
  });

  testWidgets('eraser keeps prior deletions and stops erasing during navigation', (tester) async {
    final store = TestCanvasDocumentStore(_document([_pen('a'), _pen('b', const Offset(350, 250))]));
    await pumpCanvas(tester, store);
    await _chooseTool(tester, 'erase');
    final first = await tester.startGesture(const Offset(150, 300), pointer: 1);
    await tester.pump();
    expect(find.byType(PenStroke), findsOneWidget);
    final second = await tester.startGesture(const Offset(500, 450), pointer: 2);
    await first.moveTo(const Offset(400, 300));
    await second.up();
    await first.moveTo(const Offset(400, 300));
    await first.up();
    await tester.pump();
    expect(find.byType(PenStroke), findsOneWidget);
    await pumpPastSave(tester);
    expect(store.persisted!.elements.map((element) => element.id), ['b']);
    await _undo(tester);
    expect(find.byType(PenStroke), findsNWidgets(2));
  });

  for (final control in ['code-block-handle', 'code-block-rotate-control', 'code-block-resize-handle']) {
    testWidgets('$control hands off without further object changes', (tester) async {
      await pumpCanvas(tester, TestCanvasDocumentStore(_document([_code()])));
      final model = tester.widget<CodeTool>(find.byType(CodeTool)).model;
      await tester.tapAt(const Offset(220, 300));
      await tester.pumpAndSettle();
      final first = await tester.startGesture(tester.getCenter(find.byKey(ValueKey(control))), pointer: 1);
      await first.moveBy(const Offset(40, 30));
      await tester.pump();
      final edited = (model.data.position, model.size, model.rotation);
      expect(edited, isNot((const Offset(180, 220), const Size(280, 240), 0)));
      final second = await tester.startGesture(const Offset(600, 450), pointer: 2);
      await first.moveBy(const Offset(30, 20));
      await second.moveBy(const Offset(30, 20));
      expect(_canvas(tester).offset, isNot(Offset.zero));
      expect((model.data.position, model.size, model.rotation), edited);
      await second.up();
      await first.moveBy(const Offset(30, 20));
      await first.up();
      expect((model.data.position, model.size, model.rotation), edited);
      FocusManager.instance.primaryFocus?.unfocus();
      await _undo(tester);
      final restored = tester.widget<CodeTool>(find.byType(CodeTool)).model;
      expect(
        (restored.data.position, restored.size, restored.rotation),
        (const Offset(180, 220), const Size(280, 240), 0),
      );
      await tester.pump(const Duration(milliseconds: 150));
    });
  }

  testWidgets('pinch from a code title does not activate on final release', (tester) async {
    await pumpCanvas(tester, TestCanvasDocumentStore(_document([_code()])));
    final model = tester.widget<CodeTool>(find.byType(CodeTool)).model;
    final title = find.text('title');
    final first = await tester.startGesture(tester.getCenter(title), pointer: 1);
    final second = await tester.startGesture(const Offset(600, 450), pointer: 2);
    // No pump between takeover and release: guards must work synchronously.
    await second.up();
    await first.up();
    await tester.pump();
    expect(model.active, isFalse);
    expect(model.focusNode.hasFocus, isFalse);
    await tester.tapAt(tester.getCenter(title));
    await tester.pump();
    expect(model.active, isTrue);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('arrow point editing freezes while its pointers navigate', (tester) async {
    await pumpCanvas(
      tester,
      TestCanvasDocumentStore(
        _document([
          ArrowElementData(
            id: 'arrow',
            start: const Offset(200, 300),
            control: const Offset(350, 300),
            end: const Offset(500, 300),
            color: 0xff000000,
            strokeStyle: ArrowStrokeStyle.solid,
            strokeWidth: 3,
          ),
        ]),
      ),
    );
    final model = tester.widget<Arrow>(find.byType(Arrow)).model;
    await tester.tapAt(const Offset(350, 300));
    await tester.pumpAndSettle();
    final first = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('arrow-end-handle'))),
      pointer: 1,
    );
    await first.moveBy(const Offset(40, 30));
    final edited = model.data.end;
    expect(edited, isNot(const Offset(500, 300)));
    final second = await tester.startGesture(const Offset(600, 450), pointer: 2);
    await first.moveBy(const Offset(30, 20));
    await second.moveBy(const Offset(30, 20));
    expect(_canvas(tester).offset, isNot(Offset.zero));
    expect(model.data.end, edited);
    await second.up();
    await first.up();
    await _undo(tester);
    expect(tester.widget<Arrow>(find.byType(Arrow)).model.data.end, const Offset(500, 300));
  });
}

// ---------- Helpers and fixtures ----------

LazyCanvasController _canvas(WidgetTester tester) => tester.widget<LazyCanvas>(find.byType(LazyCanvas)).controller;

Future<void> _chooseTool(WidgetTester tester, String tool) async {
  await tester.tap(find.byKey(ValueKey('toolbar-$tool')));
  await tester.pump();
}

Future<void> _undo(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

CanvasDocument _document([List<CanvasElementData> elements = const []]) =>
    CanvasDocument(background: CanvasBackgroundKind.plain, elements: elements);

PenElementData _pen(String id, [Offset position = const Offset(100, 250)]) => PenElementData(
  id: id,
  position: position,
  size: const Size(100, 100),
  hitSlop: 6,
  color: 0xff000000,
  width: 3,
  points: const [PenPointData(Offset(0, 50), pressure: 0.5), PenPointData(Offset(100, 50), pressure: 0.5)],
);

CodeElementData _code() => CodeElementData(
  id: 'code',
  position: const Offset(180, 220),
  size: const Size(280, 240),
  language: CodeLanguage.dart,
  source: 'value',
  title: 'title',
  showLineNumbers: true,
);
