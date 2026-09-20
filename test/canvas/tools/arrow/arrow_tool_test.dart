// Verifies arrow creation, editing, rendering, and toolbar behavior.
// Exercises the arrow tool through model and canvas widget flows.

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_background.dart';
import 'package:beyond/canvas/editor/widgets/toolbar_button.dart';
import 'package:beyond/canvas/persistence/canvas_document_store.dart';
import 'package:beyond/canvas/tools/arrow/arrow_tool.dart';
import 'package:beyond/theme/preset_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

import '../../test_helpers.dart';

// ---------- Tests ----------

void main() {
  setUp(() async {
    SharedPreferencesAsyncWeb.registerWith(null);
    final preferences = SharedPreferencesAsync();
    await preferences.remove(CanvasDocumentStore.key);
    await preferences.remove('interface.no_icons');
  });

  test('arrow bends continuously toward the visual counterclockwise side', () {
    const directions = [
      (start: Offset.zero, end: Offset(100, 0), side: Offset(0, -1)),
      (start: Offset(100, 0), end: Offset.zero, side: Offset(0, 1)),
      (start: Offset(0, 100), end: Offset.zero, side: Offset(-1, 0)),
      (start: Offset.zero, end: Offset(0, 100), side: Offset(1, 0)),
    ];

    Offset bend(Offset start, Offset end) {
      final vector = end - start;
      final control = arrowControlPoint(start: start, end: end);
      return control - (start + vector * 0.5);
    }

    for (final direction in directions) {
      final offset = bend(direction.start, direction.end);
      expect(
        offset.dx * direction.side.dx + offset.dy * direction.side.dy,
        greaterThan(0),
      );
    }

    const start = Offset(40, 80);
    const firstEnd = Offset(340, 180);
    const secondEnd = Offset(340.1, 180.1);
    final firstBend = bend(start, firstEnd);
    final secondBend = bend(start, secondEnd);
    expect((secondBend - firstBend).distance, lessThan(0.1));
    expect(
      firstBend.dx * secondBend.dx + firstBend.dy * secondBend.dy,
      greaterThan(0),
    );
  });

  test('arrow tool previews, commits on up, and discards tiny drags', () {
    final committed = <ArrowModel>[];
    final tool = ArrowTool(onArrow: committed.add)
      ..setColor(const Color(0xffd85b5b))
      ..setStrokeStyle(ArrowStrokeStyle.dashed)
      ..setStrokeWidth(3);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);

    tool.onPointerDown(
      pointer.down(const Offset(10, 20)),
      const Offset(10, 20),
    );
    expect(tool.preview, isNotNull);
    tool.onPointerMove(
      pointer.move(const Offset(120, 80)),
      const Offset(120, 80),
    );
    expect(tool.preview!.geometry.start, const Offset(10, 20));
    expect(tool.preview!.geometry.end, const Offset(120, 80));
    expect(tool.preview!.color, const Color(0xffd85b5b));
    expect(tool.preview!.strokeStyle, ArrowStrokeStyle.dashed);
    expect(tool.preview!.strokeWidth, 3);
    expect(committed, isEmpty);

    tool.onPointerUp(
      pointer.up(),
      const Offset(120, 80),
    );
    expect(committed, hasLength(1));
    expect(committed.single.start, const Offset(10, 20));
    expect(committed.single.end, const Offset(120, 80));
    expect(committed.single.color, const Color(0xffd85b5b));
    expect(committed.single.strokeStyle, ArrowStrokeStyle.dashed);
    expect(committed.single.strokeWidth, 3);
    final bounds = committed.single.bounds;
    committed.single.strokeWidth = arrowStrokeWidthMaximum;
    expect(committed.single.bounds, bounds);
    expect(tool.preview, isNull);

    final tinyPointer = TestPointer(2, PointerDeviceKind.mouse);
    tool
      ..onPointerDown(
        tinyPointer.down(const Offset(200, 200)),
        const Offset(200, 200),
      )
      ..onPointerUp(
        tinyPointer.up(),
        const Offset(202, 201),
      );
    expect(committed, hasLength(1));
    tool.dispose();
    committed.single.dispose();
  });

  test('arrow points edit independently and preserve minimum length', () {
    final model = ArrowModel(
      ArrowElementData(
        id: 'arrow',
        start: const Offset(10, 20),
        control: const Offset(60, 5),
        end: const Offset(110, 40),
        color: Colors.black.toARGB32(),
        strokeStyle: ArrowStrokeStyle.solid,
        strokeWidth: 2,
      ),
    );

    expect(model.setPoint(ArrowPoint.control, const Offset(70, 10)), isTrue);
    expect(model.start, const Offset(10, 20));
    expect(model.control, const Offset(70, 10));
    expect(model.end, const Offset(110, 40));

    model.setPoint(ArrowPoint.end, model.start);
    expect(
      (model.end - model.start).distance,
      greaterThanOrEqualTo(arrowMinimumLength),
    );
    expect(
      () => ArrowElementData.fromJson(model.data.toJson()),
      returnsNormally,
    );
    model.dispose();
  });

  testWidgets('active arrows expose zoom-aware editable points with one-step undo', (tester) async {
    await pumpCanvas(tester, TestCanvasDocumentStore(_arrowDocument()));
    final arrowFinder = find.byType(Arrow);
    var model = tester.widget<Arrow>(arrowFinder).model;

    expect(find.byKey(const ValueKey('arrow-start-handle')), findsNothing);
    final curvePoint = model.start * 0.25 + model.control * 0.5 + model.end * 0.25;
    await tester.tapAt(
      tester.getTopLeft(arrowFinder) + curvePoint - model.bounds.topLeft,
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('arrow-bezier-guides')), findsOneWidget);
    expect(find.byKey(const ValueKey('arrow-start-handle')), findsOneWidget);
    expect(find.byKey(const ValueKey('arrow-control-handle')), findsOneWidget);
    expect(find.byKey(const ValueKey('arrow-end-handle')), findsOneWidget);

    final originalEnd = model.end;
    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    canvas.controller.updateScalebyDelta(1, focalPoint: Offset.zero);
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('arrow-end-handle')),
      const Offset(40, 20),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    expect(model.end, originalEnd + const Offset(20, 10));
    expect(
      canvas.controller.widgetsWithScreenPositions().single.gsPosition,
      model.canvasPosition,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    model = tester.widget<Arrow>(arrowFinder).model;
    expect(model.end, originalEnd);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('arrow-control-handle')), findsNothing);
  });

  testWidgets('arrows place once, select by click and marquee, and move', (
    tester,
  ) async {
    await pumpBeyondApp(tester);

    await tester.tap(find.byKey(const ValueKey('toolbar-arrow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('arrow-settings-panel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('arrow-style-dashed')));
    await tester.tap(find.byKey(const ValueKey('color-preset-Red')));
    tester.widget<Slider>(find.byKey(const ValueKey('discrete-slider'))).onChanged!(3);
    await tester.pump();
    final firstDrag = await tester.startGesture(
      const Offset(120, 200),
      kind: PointerDeviceKind.mouse,
    );
    await firstDrag.moveTo(const Offset(300, 260));
    await tester.pump();
    expect(find.byKey(const ValueKey('arrow-preview')), findsOneWidget);
    expect(find.byType(Arrow), findsNothing);
    await firstDrag.up();
    await tester.pump();

    expect(find.byType(Arrow), findsOneWidget);
    final first = tester.widget<Arrow>(find.byType(Arrow)).model;
    expect(first.start, const Offset(120, 200));
    expect(first.end, const Offset(300, 260));
    expect(first.strokeStyle, ArrowStrokeStyle.dashed);
    expect(
      first.color.toARGB32(),
      presetColors.firstWhere((swatch) => swatch.label == 'Red').color.toARGB32(),
    );
    expect(first.strokeWidth, 3);
    expect(find.byKey(const ValueKey('arrow-settings-panel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('arrow-style-solid')));
    await tester.pump();
    expect(first.strokeStyle, ArrowStrokeStyle.solid);
    final toolbar = find.byKey(const ValueKey('toolbar-arrow'));
    expect(tester.widget<ToolbarButton>(toolbar).selected, isFalse);

    final secondDrag = await tester.startGesture(
      const Offset(420, 200),
      kind: PointerDeviceKind.mouse,
    );
    await secondDrag.moveTo(const Offset(560, 260));
    await secondDrag.up();
    await tester.pump();
    expect(find.byType(Arrow), findsOneWidget);

    final arrowFinder = find.byType(Arrow).first;
    final arrowTopLeft = tester.getTopLeft(arrowFinder);
    final startPoint =
        arrowTopLeft +
        Offset(
          first.start.dx - first.bounds.left,
          first.start.dy - first.bounds.top,
        );
    await tester.tapAt(startPoint);
    await tester.pump();
    expect(first.active, isTrue);
    expect(first.selected, isTrue);
    expect(find.byKey(const ValueKey('arrow-block-handle')), findsWidgets);
    expect(find.byKey(const ValueKey('arrow-block-delete-control')), findsWidgets);
    expect(find.byKey(const ValueKey('arrow-block-rotate-control')), findsNothing);

    const moveDelta = Offset(40, 30);
    final move = await tester.startGesture(
      startPoint,
      kind: PointerDeviceKind.mouse,
    );
    await move.moveBy(moveDelta);
    await move.up();
    await tester.pump();
    expect(first.start, const Offset(160, 230));

    final marquee = await tester.startGesture(
      const Offset(80, 150),
      kind: PointerDeviceKind.mouse,
    );
    await marquee.moveTo(const Offset(350, 330));
    await tester.pump();
    expect(first.selected, isTrue);
    await marquee.up();
  });
}

CanvasDocument _arrowDocument() => CanvasDocument(
  background: CanvasBackgroundKind.plain,
  elements: [
    ArrowElementData(
      id: 'arrow',
      start: const Offset(120, 200),
      control: const Offset(210, 160),
      end: const Offset(300, 240),
      color: Colors.black.toARGB32(),
      strokeStyle: ArrowStrokeStyle.solid,
      strokeWidth: 2,
    ),
  ],
);
