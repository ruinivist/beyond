import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/canvas_page.dart';
import 'package:beyond/canvas/tools/shape/shape_tool.dart';
import 'package:beyond/foundation/button.dart';
import 'package:beyond/theme/starless.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

void main() {
  setUp(() => SharedPreferencesAsyncWeb.registerWith(null));

  test('shape tool normalizes drags and rejects undersized shapes', () {
    final shapes = <ShapeModel>[];
    final tool = ShapeTool(onShape: shapes.add)..setKind(ShapeKind.diamond);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);

    tool
      ..onPointerDown(
        pointer.down(const Offset(180, 140)),
        const Offset(180, 140),
      )
      ..onPointerMove(
        pointer.move(const Offset(40, 20)),
        const Offset(40, 20),
      );
    expect(tool.preview!.rect, const Rect.fromLTRB(40, 20, 180, 140));
    tool.onPointerUp(pointer.up(), const Offset(40, 20));

    expect(shapes, hasLength(1));
    expect(shapes.single.data.kind, ShapeKind.diamond);
    expect(shapes.single.data.position, const Offset(40, 20));
    expect(shapes.single.data.size, const Size(140, 120));
    expect(tool.preview, isNull);

    final tiny = TestPointer(2, PointerDeviceKind.mouse);
    tool
      ..onPointerDown(
        tiny.down(const Offset(200, 200)),
        const Offset(200, 200),
      )
      ..onPointerUp(tiny.up(), const Offset(220, 220));
    expect(shapes, hasLength(1));

    tool.dispose();
    for (final shape in shapes) {
      shape.dispose();
    }
  });

  testWidgets('hollow shapes hit their full geometric area', (tester) async {
    final model = ShapeModel(
      ShapeElementData(
        id: 'ellipse',
        kind: ShapeKind.ellipse,
        position: Offset.zero,
        size: const Size(200, 100),
      ),
    );
    var backgroundTaps = 0;
    var shapeTaps = 0;
    var topTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => backgroundTaps++,
              ),
            ),
            Positioned(
              left: 100,
              top: 100,
              child: SizedBox.fromSize(
                size: model.canvasSize,
                child: Listener(
                  onPointerDown: (_) => shapeTaps++,
                  child: Shape(
                    model: model,
                    onMove: (_) {},
                    onResize: (_) {},
                  ),
                ),
              ),
            ),
            Positioned(
              left: 175,
              top: 125,
              width: 50,
              height: 50,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => topTaps++,
                child: const Text('Top'),
              ),
            ),
          ],
        ),
      ),
    );

    final rect = tester.getRect(find.byType(Shape));
    await tester.tapAt(rect.center + const Offset(60, 0));
    await tester.pump();
    expect(shapeTaps, 1);
    expect(backgroundTaps, 0);

    await tester.tapAt(rect.center);
    await tester.pump();
    expect(topTaps, 1);
    expect(shapeTaps, 1);

    await tester.tapAt(rect.topLeft + const Offset(2, 2));
    await tester.pump();
    expect(shapeTaps, 1);
    expect(backgroundTaps, 1);

    model.dispose();
  });

  testWidgets('toolbar draws repeatedly, selects, moves, and resizes shapes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: CanvasPage(documentStore: _DocumentStore()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();
    final toolbar = find.byKey(const ValueKey('toolbar-shape'));
    expect(tester.widget<Button>(toolbar).selected, isTrue);
    expect(find.byKey(const ValueKey('shape-settings-panel')), findsOneWidget);
    expect(
      tester
          .widget<Button>(
            find.byKey(
              const ValueKey('shape-option-roundedRectangle'),
            ),
          )
          .selected,
      isTrue,
    );

    final firstDrag = await tester.startGesture(
      const Offset(100, 180),
      kind: PointerDeviceKind.mouse,
    );
    await firstDrag.moveTo(const Offset(240, 280));
    await tester.pump();
    expect(find.byKey(const ValueKey('shape-preview')), findsOneWidget);
    await firstDrag.up();
    await tester.pump();
    expect(find.byType(Shape), findsOneWidget);
    expect(
      tester.widget<Shape>(find.byType(Shape)).model.data.kind,
      ShapeKind.roundedRectangle,
    );

    await tester.tap(
      find.byKey(const ValueKey('shape-option-diamond')),
    );
    await tester.pump();
    expect(
      (tester.widget<Button>(toolbar).child! as Icon).semanticLabel,
      'Rect',
    );

    final secondDrag = await tester.startGesture(
      const Offset(320, 180),
      kind: PointerDeviceKind.mouse,
    );
    await secondDrag.moveTo(const Offset(440, 260));
    await secondDrag.up();
    await tester.pump();
    expect(find.byType(Shape), findsNWidgets(2));
    expect(
      tester.widget<Shape>(find.byType(Shape).last).model.data.kind,
      ShapeKind.diamond,
    );
    expect(
      tester.widget<Shape>(find.byType(Shape).first).model.data.kind,
      ShapeKind.roundedRectangle,
    );
    expect(tester.widget<Button>(toolbar).selected, isTrue);

    await tester.tap(find.byKey(const ValueKey('toolbar-erase')));
    await tester.pump();
    expect(find.byKey(const ValueKey('shape-settings-panel')), findsNothing);

    await tester.tap(toolbar);
    await tester.pump();
    expect(find.byKey(const ValueKey('shape-settings-panel')), findsOneWidget);
    expect(
      tester
          .widget<Button>(
            find.byKey(
              const ValueKey('shape-option-roundedRectangle'),
            ),
          )
          .selected,
      isTrue,
    );
    final thirdDrag = await tester.startGesture(
      const Offset(500, 180),
      kind: PointerDeviceKind.mouse,
    );
    await thirdDrag.moveTo(const Offset(620, 260));
    await thirdDrag.up();
    await tester.pump();
    expect(find.byType(Shape), findsNWidgets(3));
    expect(
      tester.widget<Shape>(find.byType(Shape).last).model.data.kind,
      ShapeKind.roundedRectangle,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(tester.widget<Button>(toolbar).selected, isFalse);

    final first = tester.widget<Shape>(find.byType(Shape).first).model;
    final firstFinder = find.byWidgetPredicate(
      (widget) => widget is Shape && identical(widget.model, first),
    );
    final originalPosition = first.data.position;
    final originalSize = first.data.size;
    await tester.tapAt(tester.getCenter(firstFinder));
    await tester.pump();
    expect(first.selected, isTrue);
    expect(
      find.byKey(const ValueKey('shape-resize-handle')),
      findsOneWidget,
    );

    await tester.drag(
      firstFinder,
      const Offset(30, 20),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(first.data.position, originalPosition + const Offset(30, 20));

    await tester.drag(
      find.byKey(const ValueKey('shape-resize-handle')),
      const Offset(40, 30),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(first.data.size, originalSize + const Offset(40, 30));
  });
}

class _DocumentStore extends CanvasDocumentStore {
  @override
  Future<CanvasDocument?> load() async => null;

  @override
  Future<void> save(CanvasDocument document) async {}
}
