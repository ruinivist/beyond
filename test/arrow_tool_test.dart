import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/tools/arrow/arrow_tool.dart';
import 'package:beyond/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

void main() {
  setUp(() async {
    SharedPreferencesAsyncWeb.registerWith(null);
    await SharedPreferencesAsync().remove(CanvasDocumentStore.key);
  });

  test('arrow geometry is stable, subtly asymmetric, and head-led', () {
    const start = Offset(40, 80);
    const end = Offset(340, 180);
    final first = arrowControlPoint(
      id: 'stable-arrow',
      start: start,
      end: end,
    );
    final second = arrowControlPoint(
      id: 'stable-arrow',
      start: start,
      end: end,
    );
    expect(first, second);

    final vector = end - start;
    final controlT =
        ((first - start).dx * vector.dx + (first - start).dy * vector.dy) /
        vector.distanceSquared;
    expect(controlT, inInclusiveRange(0.44, 0.56));
    final bow = (first - (start + vector * controlT)).distance;
    expect(bow, inInclusiveRange(3 * 2 * 0.85, 16 * 2 * 1.15));

    final geometry = ArrowGeometry(start: start, control: first, end: end);
    final tangent = (end - first) / (end - first).distance;
    expect(geometry.endTangent.dx, closeTo(tangent.dx, 0.000001));
    expect(geometry.endTangent.dy, closeTo(tangent.dy, 0.000001));
  });

  test('arrow tool previews, commits on up, and discards tiny drags', () {
    final committed = <ArrowModel>[];
    final tool = ArrowTool(onArrow: committed.add);
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
    expect(committed, isEmpty);

    tool.onPointerUp(
      pointer.up(),
      const Offset(120, 80),
    );
    expect(committed, hasLength(1));
    expect(committed.single.start, const Offset(10, 20));
    expect(committed.single.end, const Offset(120, 80));
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

  testWidgets('arrows stay active, select by click and marquee, and move', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Arrow'));
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

    final secondDrag = await tester.startGesture(
      const Offset(420, 200),
      kind: PointerDeviceKind.mouse,
    );
    await secondDrag.moveTo(const Offset(560, 260));
    await secondDrag.up();
    await tester.pump();
    expect(find.byType(Arrow), findsNWidgets(2));

    await tester.tap(find.text('Arrow'));
    await tester.pump();
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
    expect(first.selected, isTrue);

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
