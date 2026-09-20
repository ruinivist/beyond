// Verifies shape creation, editing, rendering, and toolbar behavior.
// Exercises the shape tool through model and canvas widget flows.

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_background.dart';
import 'package:beyond/canvas/editor/widgets/toolbar_button.dart';
import 'package:beyond/canvas/tools/shape/shape_tool.dart';
import 'package:beyond/theme/preset_colors.dart';
import 'package:beyond/theme/starless.dart';
import 'package:beyond/ui/common/color_picker.dart';
import 'package:beyond/ui/common/discrete_slider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

import '../../test_helpers.dart';

// ---------- Tests ----------

void main() {
  setUp(() => SharedPreferencesAsyncWeb.registerWith(null));

  test('shape tool normalizes drags and rejects undersized shapes', () {
    final shapes = <ShapeModel>[];
    final tool = ShapeTool(onShape: shapes.add)
      ..setKind(ShapeKind.hexagon)
      ..setStrokeColor(const Color(0xffdc3f3f))
      ..setFillColor(const Color(0xff2f6fde))
      ..setStrokeWidth(3);
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
    expect(shapes.single.data.kind, ShapeKind.hexagon);
    expect(shapes.single.data.position, const Offset(40, 20));
    expect(shapes.single.data.size, const Size(140, 120));
    expect(shapes.single.data.strokeColor, 0xffdc3f3f);
    expect(shapes.single.data.fillColor, 0xff2f6fde);
    expect(shapes.single.data.strokeWidth, 3);
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
        strokeColor: 0xff655a53,
        fillColor: null,
        strokeWidth: 2,
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

  testWidgets('toolbar places one shape, then selects, moves, and resizes', (
    tester,
  ) async {
    await pumpCanvas(tester, TestCanvasDocumentStore());

    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();
    final toolbar = find.byKey(const ValueKey('toolbar-shape'));
    expect(tester.widget<ToolbarButton>(toolbar).selected, isTrue);
    expect(find.byKey(const ValueKey('shape-settings-panel')), findsOneWidget);
    final colorControl = tester.widget<ColorControl>(find.byType(ColorControl));
    final blue = presetColors.firstWhere((swatch) => swatch.label == 'Blue').color;
    expect(colorControl.enableAlpha, isTrue);
    colorControl.onChanged(blue);
    await tester.pump();
    expect(
      tester
          .widget<ToolbarButton>(
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
    expect(
      tester.widget<Shape>(find.byType(Shape)).model.data.strokeColor,
      blue.toARGB32(),
    );
    final first = tester.widget<Shape>(find.byType(Shape)).model;
    expect(first.active, isTrue);
    expect(first.selected, isTrue);
    expect(tester.widget<ToolbarButton>(toolbar).selected, isFalse);
    expect(find.byKey(const ValueKey('shape-settings-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shape-option-roundedRectangle')),
      findsOneWidget,
    );

    final secondDrag = await tester.startGesture(
      const Offset(320, 180),
      kind: PointerDeviceKind.mouse,
    );
    await secondDrag.moveTo(const Offset(440, 260));
    await secondDrag.up();
    await tester.pump();
    expect(find.byType(Shape), findsOneWidget);

    await tester.tap(toolbar);
    await tester.pump();
    expect(find.byKey(const ValueKey('shape-settings-panel')), findsOneWidget);
    expect(
      tester
          .widget<ToolbarButton>(
            find.byKey(
              const ValueKey('shape-option-roundedRectangle'),
            ),
          )
          .selected,
      isTrue,
    );
    tester.widget<ColorControl>(find.byType(ColorControl)).onExpandedChanged(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('color-picker-custom')), findsOneWidget);
    tester.widget<ColorControl>(find.byType(ColorControl)).onExpandedChanged(false);
    await tester.pumpAndSettle();
    final thirdDrag = await tester.startGesture(
      const Offset(500, 180),
      kind: PointerDeviceKind.mouse,
    );
    await thirdDrag.moveTo(const Offset(620, 260));
    await thirdDrag.up();
    await tester.pump();
    expect(find.byType(Shape), findsNWidgets(2));
    expect(
      tester.widget<Shape>(find.byType(Shape).last).model.data.kind,
      ShapeKind.roundedRectangle,
    );
    expect(tester.widget<ToolbarButton>(toolbar).selected, isFalse);

    final firstFinder = find.byWidgetPredicate(
      (widget) => widget is Shape && identical(widget.model, first),
    );
    final originalPosition = first.data.position;
    final originalSize = first.data.size;
    await tester.tapAt(tester.getCenter(firstFinder));
    await tester.pump();
    expect(first.active, isTrue);
    expect(first.selected, isTrue);
    expect(find.byKey(const ValueKey('shape-block-rotate-control')), findsNothing);
    expect(
      find.byKey(const ValueKey('shape-resize-handle')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('shape-block-handle')),
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

    await tester.tap(find.byKey(const ValueKey('shape-block-delete-control')));
    await tester.pump();
    expect(firstFinder, findsNothing);
  });

  testWidgets('active shape options edit, persist, undo, and follow selection rules', (tester) async {
    final store = TestCanvasDocumentStore(
      CanvasDocument(
        background: CanvasBackgroundKind.plain,
        elements: [
          ShapeElementData(
            id: 'shape',
            kind: ShapeKind.rectangle,
            position: const Offset(140, 180),
            size: const Size(120, 80),
            strokeColor: 0xff000000,
            fillColor: null,
            strokeWidth: 2,
          ),
        ],
      ),
    );
    await pumpCanvas(tester, store);

    ShapeModel model() => tester.widget<Shape>(find.byType(Shape)).model;

    await tester.tap(find.byType(Shape));
    await tester.pump();
    expect(model().active, isTrue);
    expect(model().selected, isTrue);
    expect(
      find.byKey(const ValueKey('shape-settings-panel')),
      findsOneWidget,
    );

    tester.widget<ToolbarButton>(find.byKey(const ValueKey('shape-option-ellipse'))).onPressed?.call();
    await tester.pump();
    final green = presetColors.firstWhere((swatch) => swatch.label == 'Green').color;
    final red = presetColors.firstWhere((swatch) => swatch.label == 'Red').color;
    tester.widget<ColorControl>(find.byType(ColorControl)).onChanged(green);
    await tester.pump();
    tester.widget<InkWell>(find.byKey(const ValueKey('shape-fill-red'))).onTap!();
    await tester.pump();
    tester.widget<DiscreteSlider>(find.byType(DiscreteSlider)).onChanged!(4);
    await tester.pump();

    final edited = model();
    expect(edited.kind, ShapeKind.ellipse);
    expect(edited.strokeColor, green);
    expect(edited.fillColor, red);
    expect(edited.strokeWidth, 4);
    expect(
      tester.widget<ToolbarButton>(find.byKey(const ValueKey('shape-option-ellipse'))).selected,
      isTrue,
    );
    await pumpPastSave(tester);
    expect(store.persisted!.elements.single.toJson(), edited.data.toJson());

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.byType(Shape));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(model().active, isFalse);
    expect(model().selected, isFalse);
    expect(find.byKey(const ValueKey('shape-settings-panel')), findsNothing);

    final marquee = await tester.startGesture(
      const Offset(100, 140),
      kind: PointerDeviceKind.mouse,
    );
    await marquee.moveTo(const Offset(300, 300));
    await marquee.up();
    await tester.pumpAndSettle();
    expect(model().selected, isTrue);
    expect(model().active, isFalse);
    expect(find.byKey(const ValueKey('shape-settings-panel')), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(model().strokeWidth, 2);
    expect(model().kind, ShapeKind.ellipse);
  });
}
