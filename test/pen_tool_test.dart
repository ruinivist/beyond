import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/tools/code_block/code_block.dart';
import 'package:beyond/canvas/tools/pen/pen_tool.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:scribble/scribble.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

void main() {
  setUp(() async {
    SharedPreferencesAsyncWeb.registerWith(null);
    await SharedPreferencesAsync().remove(CanvasDocumentStore.key);
  });

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

    expect(stroke.position, const Offset(94.5, 74.5));
    expect(stroke.size, const Size(61, 61));
    expect(stroke.hitSlop, 3);
    expect(stroke.sketch.lines.single.width, 2.5);
    expect(stroke.sketch.lines.single.points.first.x, 5.5);
    expect(stroke.sketch.lines.single.points.first.y, 5.5);
  });

  testWidgets('pen commits strokes and stays active', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Draw'));
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

  testWidgets('ctrl-click selects only near stroke ink', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Draw'));
    await tester.pump();
    await tester.dragFrom(const Offset(40, 300), const Offset(60, 60));
    await tester.pump();
    await tester.tap(find.text('Draw'));
    await tester.pump();

    final strokeFinder = find.byType(PenStroke);
    final stroke = tester.widget<PenStroke>(strokeFinder).model;
    final strokeTopLeft = tester.getTopLeft(strokeFinder);
    final strokeSize = tester.getSize(strokeFinder);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.tapAt(strokeTopLeft + Offset(strokeSize.width - 2, 2));
    await tester.pump();
    expect(stroke.selected, isFalse);

    await tester.tapAt(tester.getCenter(strokeFinder));
    await tester.pump();
    expect(stroke.selected, isTrue);
    final selectedStrokePosition = tester.getTopLeft(strokeFinder);
    await tester.drag(
      strokeFinder,
      const Offset(48, 36),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(tester.getTopLeft(strokeFinder), selectedStrokePosition);
    await tester.tapAt(tester.getCenter(strokeFinder));
    await tester.pump();
    expect(stroke.selected, isTrue);
    expect(
      find.descendant(
        of: strokeFinder,
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Code'));
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('code-block-header'))),
    );
    await tester.pump();
    final code = tester.widget<CodeBlock>(find.byType(CodeBlock)).model;
    expect(stroke.selected, isTrue);
    expect(code.selected, isTrue);

    await tester.tapAt(tester.getCenter(strokeFinder));
    await tester.pump();
    expect(stroke.selected, isFalse);
    expect(code.selected, isTrue);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.tapAt(const Offset(20, 220));
    await tester.pump();
    expect(code.selected, isFalse);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('enabling pen stops text editing', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.tapAt(const Offset(120, 200));
    await tester.pump();
    await tester.pump();

    final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    expect(model.editing, isTrue);
    expect(find.byType(TextBlockControls), findsOneWidget);

    await tester.tap(find.text('Draw'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(model.editing, isFalse);
    expect(find.byType(TextBlockControls), findsNothing);
  });

  testWidgets('repeated code blocks cascade down and right', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Code'));
    await tester.pump();
    await tester.tap(find.text('Code'));
    await tester.pump();
    await tester.tap(find.text('Code'));
    await tester.pump();

    final blocks = find.byType(CodeBlock);
    expect(blocks, findsNWidgets(3));
    expect(
      tester.getTopLeft(blocks.at(1)),
      tester.getTopLeft(blocks.at(0)) + const Offset(24, 24),
    );
    expect(
      tester.getTopLeft(blocks.at(2)),
      tester.getTopLeft(blocks.at(1)) + const Offset(24, 24),
    );

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
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

  testWidgets('code scroll boundary does not pan canvas', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.tap(find.text('Code'));
    await tester.pump();

    final block = find.byType(CodeBlock);
    final model = tester.widget<CodeBlock>(block).model;
    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    model.controller.text = List.generate(
      100,
      (index) => 'line $index',
    ).join('\n');
    await tester.pump();
    expect(
      model.scrollController.verticalScroller.position.maxScrollExtent,
      greaterThan(0),
    );

    model.scrollController.verticalScroller.jumpTo(
      model.scrollController.verticalScroller.position.maxScrollExtent,
    );
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(block)),
    );
    await tester.sendEventToBinding(
      pointer.scroll(const Offset(0, 20)),
    );
    await tester.pump();

    expect(canvas.controller.offset, Offset.zero);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('code blocks move from the header without selecting', (
    tester,
  ) async {
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
    expect(tester.widget<CodeBlock>(block).model.selected, isFalse);

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

  testWidgets('ctrl-click multi-selects without activating blocks', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.tapAt(const Offset(40, 520));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final text = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    final code = tester.widget<CodeBlock>(find.byType(CodeBlock)).model;
    final textCenter = tester.getCenter(
      find.byKey(const ValueKey('text-markdown-preview-surface')),
    );
    final codeHeaderCenter = tester.getCenter(
      find.byKey(const ValueKey('code-block-header')),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.tapAt(textCenter);
    await tester.pump();
    await tester.tapAt(codeHeaderCenter);
    await tester.pump();
    expect(text.selected, isTrue);
    expect(code.selected, isTrue);
    await tester.tapAt(codeHeaderCenter);
    await tester.pump();
    expect(text.selected, isTrue);
    expect(code.selected, isFalse);
    await tester.tapAt(codeHeaderCenter);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(text.selected, isTrue);
    expect(code.selected, isTrue);
    expect(text.editing, isFalse);
    expect(text.focusNode.hasFocus, isFalse);
    expect(code.focusNode.hasFocus, isFalse);
    final selectedSemantics = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.selected == true,
    );
    expect(
      find.descendant(of: find.byType(TextBlock), matching: selectedSemantics),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(CodeBlock), matching: selectedSemantics),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('text-markdown-preview-surface')),
    );
    await tester.pump();
    expect(text.editing, isTrue);
    expect(text.selected, isFalse);
    expect(code.selected, isFalse);

    await tester.tapAt(const Offset(20, 300));
    await tester.pump();
    expect(text.selected, isFalse);
    expect(code.selected, isFalse);
  });

  testWidgets('dragging a selected mixed group moves every child', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.tapAt(const Offset(40, 520));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Draw'));
    await tester.pump();
    await tester.dragFrom(
      const Offset(350, 540),
      const Offset(50, 20),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.tap(find.text('Draw'));
    await tester.tap(find.text('Code'));
    await tester.pump(const Duration(milliseconds: 100));

    final textFinder = find.byType(TextBlock);
    final codeFinder = find.byType(CodeBlock);
    final strokeFinder = find.byType(PenStroke);
    final text = tester.widget<TextBlock>(textFinder).model;
    final code = tester.widget<CodeBlock>(codeFinder).model;
    final stroke = tester.widget<PenStroke>(strokeFinder).model;
    final textPosition = tester.getTopLeft(textFinder);
    final codePosition = tester.getTopLeft(codeFinder);
    final strokePosition = tester.getTopLeft(strokeFinder);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(
        find.byKey(const ValueKey('text-markdown-preview-surface')),
      ),
    );
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('code-block-header'))),
    );
    await tester.pump();
    await tester.tapAt(tester.getCenter(strokeFinder));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(text.selected, isTrue);
    expect(code.selected, isTrue);
    expect(stroke.selected, isTrue);

    const delta = Offset(48, 36);
    await tester.drag(strokeFinder, delta, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(tester.getTopLeft(textFinder), textPosition + delta);
    expect(tester.getTopLeft(codeFinder), codePosition + delta);
    expect(tester.getTopLeft(strokeFinder), strokePosition + delta);
    expect(text.selected, isTrue);
    expect(code.selected, isTrue);
    expect(stroke.selected, isTrue);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('resizing a selected widget clears the rest of the selection', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.tapAt(const Offset(40, 520));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Code'));
    await tester.pump(const Duration(milliseconds: 100));

    final text = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    final code = tester.widget<CodeBlock>(find.byType(CodeBlock)).model;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(
        find.byKey(const ValueKey('text-markdown-preview-surface')),
      ),
    );
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('code-block-header'))),
    );
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(text.selected, isTrue);
    expect(code.selected, isTrue);
    final originalSize = code.size;
    await tester.drag(
      find.byKey(const ValueKey('code-block-resize-handle')),
      const Offset(80, 60),
    );
    await tester.pump();

    expect(code.size, isNot(originalSize));
    expect(text.selected, isFalse);
    expect(code.selected, isFalse);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('dragging an unselected child clears selection and moves alone', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.tapAt(const Offset(40, 520));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Code'));
    await tester.pump(const Duration(milliseconds: 100));

    final textFinder = find.byType(TextBlock);
    final codeFinder = find.byType(CodeBlock);
    final text = tester.widget<TextBlock>(textFinder).model;
    final code = tester.widget<CodeBlock>(codeFinder).model;
    final header = find.byKey(const ValueKey('code-block-header'));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(
        find.byKey(const ValueKey('text-markdown-preview-surface')),
      ),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(text.selected, isTrue);
    expect(code.selected, isFalse);

    final textPosition = tester.getTopLeft(textFinder);
    final codePosition = tester.getTopLeft(codeFinder);
    const delta = Offset(72, 44);
    await tester.drag(header, delta, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(tester.getTopLeft(textFinder), textPosition);
    expect(tester.getTopLeft(codeFinder), codePosition + delta);
    expect(text.selected, isFalse);
    expect(code.selected, isFalse);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('drag marquee selects overlaps and ctrl toggles hits', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.tapAt(const Offset(40, 520));
    await tester.pump();
    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.tapAt(const Offset(500, 520));
    await tester.pump();
    await tester.tap(find.text('Draw'));
    await tester.pump();
    await tester.dragFrom(
      const Offset(350, 540),
      const Offset(50, 20),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.tap(find.text('Draw'));
    await tester.tap(find.text('Code'));
    await tester.pump(const Duration(milliseconds: 100));

    final texts = tester
        .widgetList<TextBlock>(find.byType(TextBlock))
        .map((block) => block.model)
        .toList();
    final insideText = texts.singleWhere(
      (model) => model.node.position.dx == 40,
    );
    final outsideText = texts.singleWhere(
      (model) => model.node.position.dx == 500,
    );
    final code = tester.widget<CodeBlock>(find.byType(CodeBlock)).model;
    final stroke = tester.widget<PenStroke>(find.byType(PenStroke)).model;
    expect(code.focusNode.hasFocus, isTrue);

    final marquee = await tester.startGesture(
      const Offset(20, 590),
      kind: PointerDeviceKind.mouse,
    );
    await marquee.moveTo(const Offset(380, 490));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('drag-selection-marquee')),
      findsOneWidget,
    );
    expect(insideText.selected, isTrue);
    expect(code.selected, isTrue);
    expect(stroke.selected, isTrue);
    expect(outsideText.selected, isFalse);
    expect(insideText.editing, isFalse);
    expect(code.focusNode.hasFocus, isFalse);

    await marquee.up();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('drag-selection-marquee')),
      findsNothing,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.tapAt(const Offset(640, 546));
    await tester.pump();
    expect(outsideText.selected, isTrue);

    final toggleMarquee = await tester.startGesture(
      const Offset(20, 590),
      kind: PointerDeviceKind.mouse,
    );
    await toggleMarquee.moveTo(const Offset(380, 490));
    await toggleMarquee.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(insideText.selected, isFalse);
    expect(code.selected, isFalse);
    expect(stroke.selected, isFalse);
    expect(outsideText.selected, isTrue);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('right and middle drag pan over block controls', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.tap(find.text('Code'));
    await tester.pump();

    final block = find.byType(CodeBlock);
    final model = tester.widget<CodeBlock>(block).model;
    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    final originalGridPosition = canvas.controller
        .widgetsWithScreenPositions()
        .single
        .gsPosition;

    final rightDrag = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('code-block-header'))),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await rightDrag.moveBy(const Offset(80, 60));
    await rightDrag.up();
    await tester.pump();

    expect(canvas.controller.offset, isNot(Offset.zero));
    expect(model.selected, isFalse);
    expect(
      canvas.controller.widgetsWithScreenPositions().single.gsPosition,
      originalGridPosition,
    );

    final offsetAfterRightDrag = canvas.controller.offset;
    final originalSize = model.size;
    final middleDrag = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('code-block-resize-handle')),
      ),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await middleDrag.moveBy(const Offset(40, 30));
    await middleDrag.up();
    await tester.pump();

    expect(canvas.controller.offset, isNot(offsetAfterRightDrag));
    expect(model.size, originalSize);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('space temporarily hands dragging back to the canvas', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.tap(find.text('Draw'));
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
