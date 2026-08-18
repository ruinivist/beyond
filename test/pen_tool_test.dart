import 'package:beyond/canvas/tools/code_block/code_block.dart';
import 'package:beyond/canvas/tools/markdown/markdown_block.dart';
import 'package:beyond/canvas/tools/pen/pen_tool.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
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
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Pen'));
    await tester.pump();
    await tester.dragFrom(const Offset(100, 200), const Offset(80, 40));
    await tester.pump();

    expect(find.byType(ScribbleSketch), findsOneWidget);
    expect(find.byType(Scribble), findsOneWidget);
  });

  testWidgets('inactive pen does not draw', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.dragFrom(const Offset(100, 200), const Offset(80, 40));
    await tester.pump();

    expect(find.byType(ScribbleSketch), findsNothing);
  });

  testWidgets('blocks added after strokes stay below them', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Pen'));
    await tester.pump();
    await tester.dragFrom(const Offset(20, 500), const Offset(40, 20));
    await tester.pump();
    await tester.tap(find.text('Code'));
    await tester.pump();

    expect(_topCanvasChild(tester), isA<SizedBox>());

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('raised blocks stay below strokes', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Code'));
    await tester.pump();
    await tester.tap(find.text('Pen'));
    await tester.pump();
    await tester.dragFrom(const Offset(20, 500), const Offset(40, 20));
    await tester.pump();
    await tester.tap(find.text('Pen'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('code-block-header')));
    await tester.pump();

    expect(_topCanvasChild(tester), isA<SizedBox>());

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('text places one block at the clicked position', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const ValueKey('text-block-handle')), findsNothing);
    await tester.tap(find.text('Text'));
    await tester.pump();

    const firstPosition = Offset(120, 200);
    await tester.tapAt(firstPosition);
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.getTopLeft(find.byType(TextField)), firstPosition);
    expect(find.byKey(const ValueKey('text-block-handle')), findsOneWidget);

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('text-block-handle')), findsOneWidget);

    await tester.tap(find.text('Text'));
    await tester.pump();
    const secondPosition = Offset(400, 300);
    await tester.tapAt(secondPosition);
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.getTopLeft(find.byType(TextField).at(1)), secondPosition);
  });

  testWidgets('text blocks move from their handle', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.tapAt(const Offset(120, 200));
    await tester.pump();
    await tester.pump();

    final textBlock = find.byType(TextBlock);
    final handle = find.byKey(const ValueKey('text-block-handle'));
    final model = tester.widget<TextBlock>(textBlock).model;
    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    final originalTopLeft = tester.getTopLeft(textBlock);
    final originalCanvasOffset = canvas.controller.offset;
    const delta = Offset(80, 60);

    await tester.drag(handle, delta, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(tester.getTopLeft(textBlock), originalTopLeft + delta);
    expect(canvas.controller.offset, originalCanvasOffset);
    expect(model.focusNode.hasFocus, isTrue);
    expect(handle, findsOneWidget);
    final focusedHintPosition = tester.getTopLeft(find.text('Type something'));

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.byKey(const ValueKey('text-block-handle')), findsNothing);
    expect(tester.getTopLeft(find.text('Type something')), focusedHintPosition);
  });

  testWidgets('code blocks resize from the bottom-right handle', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final block = find.byType(CodeBlock);
    final handle = find.byKey(const ValueKey('code-block-resize-handle'));
    final originalSize = tester.getSize(block);

    expect(handle, findsOneWidget);
    await tester.drag(handle, const Offset(80, 60));
    await tester.pump();

    final enlargedSize = tester.getSize(block);
    expect(enlargedSize.width, greaterThan(originalSize.width));
    expect(enlargedSize.height, greaterThan(originalSize.height));

    await tester.drag(handle, const Offset(-1000, -1000));
    await tester.pump();

    expect(tester.getSize(block), codeBlockMinimumSize);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
  });

  testWidgets('code blocks select and move from the header', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final block = find.byType(CodeBlock);
    final header = find.byKey(const ValueKey('code-block-header'));
    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    final originalTopLeft = tester.getTopLeft(block);
    final originalCanvasOffset = canvas.controller.offset;

    expect(tester.widget<CodeBlock>(block).model.selected, isFalse);

    await tester.tap(header);
    await tester.pump();
    expect(tester.widget<CodeBlock>(block).model.selected, isTrue);

    const delta = Offset(80, 60);
    await tester.drag(header, delta);
    await tester.pump();

    expect(tester.getTopLeft(block), originalTopLeft + delta);
    expect(canvas.controller.offset, originalCanvasOffset);

    await tester.tapAt(const Offset(24, 200));
    await tester.pump();
    expect(tester.widget<CodeBlock>(block).model.selected, isFalse);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
  });

  testWidgets('last interacted block moves to front', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Code'));
    await tester.pump();
    await tester.tap(find.text('Markdown'));
    await tester.pump();
    await tester.pump();

    final code = tester.widget<CodeBlock>(find.byType(CodeBlock)).model;
    final markdown = tester
        .widget<MarkdownBlock>(find.byType(MarkdownBlock))
        .model;

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(markdown.selected, isTrue);

    await tester.tapAt(const Offset(110, 300));
    await tester.pump();
    expect(code.selected, isTrue);

    await tester.tapAt(const Offset(24, 550));
    await tester.pump();
    expect(code.selected, isFalse);

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(code.selected, isTrue);
    expect(markdown.selected, isFalse);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('space temporarily hands dragging back to the canvas', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
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

Widget _topCanvasChild(WidgetTester tester) {
  final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
  final wrapper = canvas.controller.widgetsWithScreenPositions().last.child;
  return (wrapper as Container).child!;
}
