import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane/canvas_page.dart';
import 'package:plane/tools/pen/pen_tool.dart';
import 'package:scribble/scribble.dart';

void main() {
  test('positions a screen stroke in canvas coordinates', () {
    final stroke = positionSketch(
      const Sketch(
        lines: [
          SketchLine(
            points: [Point(100, 200), Point(200, 300)],
            color: 0xff000000,
            width: 5,
          ),
        ],
      ),
      canvasOffset: const Offset(50, -20),
      canvasScale: 2,
    );

    expect(stroke.position, const Offset(97.5, 77.5));
    expect(stroke.size, const Size(55, 55));
    expect(stroke.sketch.lines.single.width, 2.5);
    expect(stroke.sketch.lines.single.points.first.x, 2.5);
    expect(stroke.sketch.lines.single.points.first.y, 2.5);
  });

  testWidgets('pen commits strokes and stays active', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CanvasPage()));
    await tester.pump();

    await tester.tap(find.text('Pen'));
    await tester.pump();
    await tester.dragFrom(const Offset(100, 200), const Offset(80, 40));
    await tester.pump();

    expect(find.byType(ScribbleSketch), findsOneWidget);
    expect(find.byType(Scribble), findsOneWidget);
  });

  testWidgets('inactive pen does not draw', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CanvasPage()));
    await tester.pump();

    await tester.dragFrom(const Offset(100, 200), const Offset(80, 40));
    await tester.pump();

    expect(find.byType(ScribbleSketch), findsNothing);
  });

  testWidgets('space temporarily hands dragging back to the canvas', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CanvasPage()));
    await tester.pump();
    await tester.tap(find.text('Pen'));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    final penInput = find.byWidgetPredicate(
      (widget) => widget is IgnorePointer && widget.child is Scribble,
    );
    expect(tester.widget<IgnorePointer>(penInput).ignoring, isTrue);
    await tester.dragFrom(const Offset(100, 200), const Offset(80, 40));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.byType(ScribbleSketch), findsNothing);

    await tester.dragFrom(const Offset(100, 200), const Offset(80, 40));
    await tester.pump();
    expect(find.byType(ScribbleSketch), findsOneWidget);
  });
}
