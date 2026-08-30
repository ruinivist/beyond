import 'dart:convert';

import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/tools/arrow/arrow_tool.dart';
import 'package:beyond/canvas/tools/code_block/code_block.dart';
import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:beyond/canvas/tools/pen/pen_tool.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/foundation/button.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/main.dart';
import 'package:beyond/utils/preset_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

void main() {
  setUp(() async {
    SharedPreferencesAsyncWeb.registerWith(null);
    final preferences = SharedPreferencesAsync();
    await preferences.remove(CanvasDocumentStore.key);
    await preferences.remove('interface.no_icons');
  });

  testWidgets('toolbar icons can be replaced with persistent labels', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    const tools = ['text', 'code', 'draw', 'erase', 'arrow'];
    for (final tool in tools) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('toolbar-$tool')),
          matching: find.byType(Icon),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('Text'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interface'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('no-icons-switch')));
    await tester.pumpAndSettle();

    expect(find.text('Text'), findsOneWidget);
    expect(
      await SharedPreferencesAsync().getBool('interface.no_icons'),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('Text'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('toolbar-text')),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
  });

  testWidgets('keyboard shortcuts toggle tools and escape disables them', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    const shortcuts = [
      (LogicalKeyboardKey.keyT, 'text'),
      (LogicalKeyboardKey.keyC, 'code'),
      (LogicalKeyboardKey.keyP, 'draw'),
      (LogicalKeyboardKey.keyE, 'erase'),
      (LogicalKeyboardKey.keyA, 'arrow'),
    ];
    for (final (key, name) in shortcuts) {
      final button = find.byKey(ValueKey('toolbar-$name'));
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(tester.widget<Button>(button).selected, isTrue);

      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(tester.widget<Button>(button).selected, isFalse);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      tester
          .widget<Button>(find.byKey(const ValueKey('toolbar-draw')))
          .selected,
      isFalse,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(
      tester
          .widget<Button>(find.byKey(const ValueKey('toolbar-draw')))
          .selected,
      isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.tapAt(const Offset(100, 160));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('text-markdown-editor')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    expect(
      tester
          .widget<Button>(find.byKey(const ValueKey('toolbar-draw')))
          .selected,
      isFalse,
    );
    FocusManager.instance.primaryFocus?.unfocus();
  });

  test('positions a screen stroke in canvas coordinates', () {
    final stroke = positionStroke(
      (
        points: const [
          PenPointData(Offset(100, 200), pressure: 0.5),
          PenPointData(Offset(200, 300), pressure: 0.5),
        ],
        color: 0xff000000,
        width: 5.0,
      ),
      id: 'pen',
      canvasOffset: const Offset(50, -20),
      canvasScale: 2,
    );

    expect(stroke.position, const Offset(94.5, 74.5));
    expect(stroke.size, const Size(61, 61));
    expect(stroke.hitSlop, 3);
    expect(stroke.width, 2.5);
    expect(stroke.points.first.position.dx, 5.5);
    expect(stroke.points.first.position.dy, 5.5);
  });

  test('pen normalizes pressure and filters non-owner or nearby points', () {
    final strokes = <RawPenStroke>[];
    final tool = PenTool(onStroke: strokes.add)
      ..onPointerDown(
        const PointerDownEvent(
          pointer: 1,
          kind: PointerDeviceKind.stylus,
          pressure: 0.5,
          pressureMin: 0.2,
          pressureMax: 0.8,
        ),
      )
      ..onPointerUpdate(
        const PointerMoveEvent(pointer: 2, position: Offset(10, 0)),
      )
      ..onPointerHover(
        const PointerHoverEvent(pointer: 2, position: Offset(10, 0)),
      )
      ..onPointerUp(
        const PointerUpEvent(pointer: 2, position: Offset(10, 0)),
      )
      ..onPointerUpdate(
        const PointerMoveEvent(pointer: 1, position: Offset(2, 0)),
      )
      ..onPointerUpdate(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(3, 0),
          pressure: 0.8,
          pressureMin: 0.2,
          pressureMax: 0.8,
        ),
      )
      ..onPointerUp(
        const PointerUpEvent(
          pointer: 1,
          position: Offset(6, 0),
          pressureMin: 0,
          pressureMax: 0,
        ),
      );

    expect(strokes, hasLength(1));
    expect(
      strokes.single.points.map((point) => point.position),
      const [Offset.zero, Offset(3, 0), Offset(6, 0)],
    );
    expect(strokes.single.points.first.pressure, closeTo(0.5, 0.0001));
    expect(strokes.single.points[1].pressure, closeTo(1, 0.0001));
    expect(strokes.single.points.last.pressure, 0.5);
    tool.dispose();
  });

  test('pen cancel and exit each commit once and clear ownership', () {
    final strokes = <RawPenStroke>[];
    final tool = PenTool(onStroke: strokes.add)
      ..onPointerDown(const PointerDownEvent(pointer: 1))
      ..onPointerCancel(
        const PointerCancelEvent(pointer: 1, position: Offset(4, 0)),
      )
      ..onPointerCancel(const PointerCancelEvent(pointer: 1))
      ..onPointerDown(
        const PointerDownEvent(pointer: 2, position: Offset(10, 0)),
      )
      ..onPointerExit(
        const PointerExitEvent(pointer: 2, position: Offset(14, 0)),
      )
      ..onPointerExit(const PointerExitEvent(pointer: 2));

    expect(strokes, hasLength(2));
    expect(tool.active, isFalse);
    tool.dispose();
  });

  test('positioned pen models keep durable geometry when moved', () {
    final model = PenStrokeModel(
      PenElementData(
        id: 'pen',
        position: const Offset(10, 20),
        size: const Size(61, 61),
        hitSlop: 3,
        color: 0xff000000,
        width: 2.5,
        points: const [
          PenPointData(Offset(5.5, 5.5), pressure: 0.5),
        ],
      ),
    )..moveBy(const Offset(8, -4));

    expect(model.data.position, const Offset(18, 16));
    expect(model.data.size, const Size(61, 61));
    expect(model.data.points.single.position.dx, 5.5);
    model.dispose();
  });

  test('code source edits update durable data', () {
    final model = CodeBlockModel(
      CodeElementData(
        id: 'code',
        position: Offset.zero,
        size: const Size(280, 240),
        language: CodeLanguage.dart,
        source: '',
      ),
    );

    model.controller.text = 'void main() {}';

    expect(model.data.source, 'void main() {}');
    model.moveBy(const Offset(4, 6));
    expect(model.data.position, const Offset(4, 6));
    model.dispose();
  });

  test('arrow movement shifts every durable point equally', () {
    final model = ArrowModel(
      ArrowElementData(
        id: 'arrow',
        start: Offset.zero,
        control: const Offset(20, -8),
        end: const Offset(40, 10),
      ),
    );
    final before = model.geometry;

    model.moveBy(const Offset(12, 7));

    expect(model.geometry.start, before.start + const Offset(12, 7));
    expect(model.geometry.control, before.control + const Offset(12, 7));
    expect(model.geometry.end, before.end + const Offset(12, 7));
    model.dispose();
  });

  testWidgets('all element types restore in document order', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('toolbar-text')));
    await tester.pump();
    await tester.tapAt(const Offset(40, 160));
    await tester.pump();
    await tester.pump();
    final text = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    final textPosition = text.data.position;
    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      'saved text',
    );

    await _placeCodeBlock(tester, const Offset(120, 100));
    final code = tester.widget<CodeBlock>(find.byType(CodeBlock)).model
      ..language = CodeLanguage.json
      ..controller.text = '{"saved": true}';
    final codePosition = code.data.position;
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();
    await tester.dragFrom(
      const Offset(40, 520),
      const Offset(100, 40),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    final pen = tester.widget<PenStroke>(find.byType(PenStroke)).model;
    final penPosition = pen.data.position;
    final penSize = pen.data.size;
    final penPoints = pen.data.toJson()['points'];
    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('toolbar-arrow')));
    await tester.pump();
    final arrowDrag = await tester.startGesture(
      const Offset(520, 520),
      kind: PointerDeviceKind.mouse,
    );
    await arrowDrag.moveTo(const Offset(700, 560));
    await arrowDrag.up();
    await tester.pump();
    final arrow = tester.widget<Arrow>(find.byType(Arrow)).model;
    final arrowGeometry = arrow.geometry;

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pump();
    await tester.tap(find.text('Canvas'));
    await tester.pump();
    tester
        .widget<Select<CanvasBackgroundKind>>(
          find.byKey(const ValueKey('canvas-background-select')),
        )
        .onChanged!
        .call(CanvasBackgroundKind.plain);
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();

    final saved = await SharedPreferencesAsync().getString(
      CanvasDocumentStore.key,
    );
    final document = CanvasDocument.fromJson(jsonDecode(saved!));
    final ids = document.elements.map((element) => element.id).toList();
    expect(document.background, CanvasBackgroundKind.plain);
    expect(document.elements, hasLength(4));
    expect(document.elements.map((element) => element.type), [
      'text',
      'code',
      'pen',
      'arrow',
    ]);
    expect((document.elements[0] as TextElementData).markdown, 'saved text');
    expect((document.elements[0] as TextElementData).position, textPosition);
    expect(
      (document.elements[1] as CodeElementData).language,
      CodeLanguage.json,
    );
    expect((document.elements[1] as CodeElementData).position, codePosition);
    expect((document.elements[2] as PenElementData).position, penPosition);
    expect((document.elements[2] as PenElementData).size, penSize);
    expect(
      (document.elements[2] as PenElementData).toJson()['points'],
      penPoints,
    );
    expect(
      (document.elements[3] as ArrowElementData).start,
      arrowGeometry.start,
    );
    expect(
      (document.elements[3] as ArrowElementData).control,
      arrowGeometry.control,
    );
    expect((document.elements[3] as ArrowElementData).end, arrowGeometry.end);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    final restored = CanvasDocument.fromJson(
      jsonDecode(
        (await SharedPreferencesAsync().getString(
          CanvasDocumentStore.key,
        ))!,
      ),
    );
    expect(restored.elements.map((element) => element.id), ids);
    expect(find.byType(TextBlock), findsOneWidget);
    expect(find.byType(CodeBlock), findsOneWidget);
    expect(find.byType(PenStroke), findsOneWidget);
    expect(find.byType(Arrow), findsOneWidget);
    final restoredCanvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    expect(
      restoredCanvas.controller.widgetsWithScreenPositions().map(
        (child) => child.id,
      ),
      ids,
    );
    for (final block in tester.widgetList<TextBlock>(find.byType(TextBlock))) {
      expect(block.model.selected, isFalse);
      expect(block.model.focusNode.hasFocus, isFalse);
    }
    for (final block in tester.widgetList<CodeBlock>(find.byType(CodeBlock))) {
      expect(block.model.selected, isFalse);
      expect(block.model.focusNode.hasFocus, isFalse);
    }
    expect(
      tester.widget<CodeBlock>(find.byType(CodeBlock)).model.data.source,
      '{"saved": true}',
    );
    expect(
      tester.widget<TextBlock>(find.byType(TextBlock)).model.data.position,
      textPosition,
    );
    expect(
      tester.widget<CodeBlock>(find.byType(CodeBlock)).model.data.position,
      codePosition,
    );
    final restoredPen = tester.widget<PenStroke>(find.byType(PenStroke)).model;
    expect(restoredPen.data.position, penPosition);
    expect(restoredPen.data.size, penSize);
    expect(restoredPen.data.toJson()['points'], penPoints);
    final restoredArrow = tester.widget<Arrow>(find.byType(Arrow)).model;
    expect(restoredArrow.geometry.start, arrowGeometry.start);
    expect(restoredArrow.geometry.control, arrowGeometry.control);
    expect(restoredArrow.geometry.end, arrowGeometry.end);
  });

  testWidgets('pen commits strokes and stays active', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();
    await tester.dragFrom(const Offset(100, 200), const Offset(80, 40));
    await tester.pump();

    expect(find.byType(PenStroke), findsOneWidget);
    expect(find.byKey(const ValueKey('pen-preview')), findsOneWidget);
  });

  testWidgets('inactive pen does not draw', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    expect(find.byKey(const ValueKey('draw-settings-panel')), findsNothing);
    expect(find.byKey(const ValueKey('pen-preview')), findsNothing);

    await tester.dragFrom(const Offset(100, 200), const Offset(80, 40));
    await tester.pump();

    expect(find.byType(PenStroke), findsNothing);
  });

  testWidgets('pen and arrow clicks update order without modifier reorder', (
    tester,
  ) async {
    final document = CanvasDocument(
      background: CanvasBackgroundKind.plain,
      elements: [
        PenElementData(
          id: 'pen',
          position: const Offset(100, 250),
          size: const Size(100, 30),
          hitSlop: 6,
          color: 0xff000000,
          width: 3,
          points: const [
            PenPointData(Offset(0, 15), pressure: 0.5),
            PenPointData(Offset(100, 15), pressure: 0.5),
          ],
        ),
        ArrowElementData(
          id: 'arrow',
          start: const Offset(300, 250),
          control: const Offset(380, 235),
          end: const Offset(460, 250),
        ),
      ],
    );
    await SharedPreferencesAsync().setString(
      CanvasDocumentStore.key,
      jsonEncode(document.toJson()),
    );
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    final penFinder = find.byType(PenStroke);
    final arrowFinder = find.byType(Arrow);
    final pen = tester.widget<PenStroke>(penFinder).model;
    final arrow = tester.widget<Arrow>(arrowFinder).model;
    List<String> elementIds() => tester
        .widget<LazyCanvas>(find.byType(LazyCanvas))
        .controller
        .widgetsWithScreenPositions()
        .map((child) => child.id)
        .toList();

    expect(elementIds(), ['pen', 'arrow']);

    await tester.tapAt(tester.getCenter(penFinder));
    await tester.pump();
    expect(elementIds(), ['arrow', 'pen']);
    expect(pen.selected, isFalse);

    final arrowStart =
        tester.getTopLeft(arrowFinder) +
        Offset(
          arrow.start.dx - arrow.bounds.left,
          arrow.start.dy - arrow.bounds.top,
        );
    await tester.tapAt(arrowStart);
    await tester.pump();
    expect(elementIds(), ['pen', 'arrow']);
    expect(arrow.selected, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.tapAt(tester.getCenter(penFinder));
    await tester.pump();
    expect(elementIds(), ['pen', 'arrow']);
    expect(pen.selected, isTrue);

    await tester.tapAt(arrowStart);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(elementIds(), ['pen', 'arrow']);
    expect(arrow.selected, isFalse);

    await tester.pump(const Duration(milliseconds: 320));
    final saved = CanvasDocument.fromJson(
      jsonDecode(
        (await SharedPreferencesAsync().getString(
          CanvasDocumentStore.key,
        ))!,
      ),
    );
    expect(saved.elements.map((element) => element.id), ['pen', 'arrow']);
  });

  testWidgets('draw settings persist and affect only future strokes', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();
    expect(find.byKey(const ValueKey('draw-settings-panel')), findsOneWidget);
    expect(find.textContaining('px'), findsNothing);
    expect(
      tester
          .widget<Slider>(find.byKey(const ValueKey('discrete-slider')))
          .label,
      '16',
    );
    expect(
      tester
          .widget<SliderTheme>(find.byType(SliderTheme))
          .data
          .showValueIndicator,
      ShowValueIndicator.onDrag,
    );

    await tester.dragFrom(const Offset(100, 300), const Offset(80, 40));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('draw-color-red')));
    tester
        .widget<Slider>(find.byKey(const ValueKey('discrete-slider')))
        .onChanged!(2.25);
    await tester.pump();
    expect(
      tester
          .widget<Slider>(find.byKey(const ValueKey('discrete-slider')))
          .label,
      '9',
    );
    await tester.dragFrom(const Offset(100, 450), const Offset(80, 40));
    await tester.pump();

    final strokes = tester
        .widgetList<PenStroke>(find.byType(PenStroke))
        .map((stroke) => stroke.model.data)
        .toList();
    expect(strokes, hasLength(2));
    expect(strokes.first.color, presetColors.first.color.toARGB32());
    expect(strokes.first.width, 4);
    expect(
      strokes.last.color,
      presetColors
          .firstWhere((swatch) => swatch.label == 'Red')
          .color
          .toARGB32(),
    );
    expect(strokes.last.width, 2.25);

    await tester.tap(find.byKey(const ValueKey('toolbar-erase')));
    await tester.pump();
    expect(find.byKey(const ValueKey('draw-settings-panel')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();
    expect(
      tester
          .widget<Slider>(find.byKey(const ValueKey('discrete-slider')))
          .value,
      2.25,
    );
    expect(
      tester
          .widget<Slider>(find.byKey(const ValueKey('discrete-slider')))
          .label,
      '9',
    );
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('draw-color-red')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );
  });

  testWidgets('toolbar and settings island avoid overlap', (tester) async {
    tester.view.physicalSize = const Size(550, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();

    final toolbar = tester.getRect(
      find.byKey(const ValueKey('toolbar-surface')),
    );
    final settings = tester.getRect(
      find.byKey(const ValueKey('settings-button-surface')),
    );
    final panel = tester.getRect(
      find.byKey(const ValueKey('draw-settings-panel')),
    );
    expect(toolbar.center.dx, 275);
    expect(settings.top, greaterThan(toolbar.bottom));
    expect(panel.top, greaterThan(settings.bottom));
    expect(toolbar.overlaps(settings), isFalse);
    expect(settings.overlaps(panel), isFalse);
  });

  testWidgets('ctrl-click selects only near stroke ink', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();
    await tester.dragFrom(const Offset(40, 300), const Offset(60, 60));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
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

    await _placeCodeBlock(tester, const Offset(120, 100));
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

  testWidgets('code places once, returns to select, and focuses editor', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('toolbar-code')));
    await tester.pump();
    expect(find.byType(CodeBlock), findsNothing);

    await tester.tapAt(const Offset(120, 200));
    await tester.pump();
    final code = tester.widget<CodeBlock>(find.byType(CodeBlock)).model;
    expect(tester.getTopLeft(find.byType(CodeBlock)), const Offset(120, 200));
    expect(code.focusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(20, 550));
    await tester.pump();
    expect(find.byType(CodeBlock), findsOneWidget);
    expect(code.focusNode.hasFocus, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('primary+A selects and deletes offscreen mixed children', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('toolbar-text')));
    await tester.pump();
    await tester.tapAt(const Offset(40, 520));
    await tester.pump();
    await tester.pump();
    final text = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    final textId = canvas.controller.widgetsWithScreenPositions().single.id;
    canvas.controller.updatePosition(textId, const Offset(10000, 10000));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();
    await tester.dragFrom(
      const Offset(350, 540),
      const Offset(50, 20),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await _placeCodeBlock(tester, const Offset(120, 100));
    await tester.pump(const Duration(milliseconds: 100));

    final code = tester.widget<CodeBlock>(find.byType(CodeBlock)).model;
    final stroke = tester.widget<PenStroke>(find.byType(PenStroke)).model;
    final visibleIds = canvas.controller
        .widgetsWithScreenPositions()
        .map((child) => child.id)
        .toList();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(text.selected, isTrue);
    expect(code.selected, isTrue);
    expect(stroke.selected, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextBlock), findsNothing);
    expect(find.byType(CodeBlock), findsNothing);
    expect(find.byType(PenStroke), findsNothing);
    expect(canvas.controller.hasChild(textId), isFalse);
    for (final id in visibleIds) {
      expect(canvas.controller.hasChild(id), isFalse);
    }
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    final saved = await SharedPreferencesAsync().getString(
      CanvasDocumentStore.key,
    );
    final savedNodes = CanvasDocument.fromJson(jsonDecode(saved!)).elements;
    expect(savedNodes, hasLength(0));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();
  });

  testWidgets('enabling pen stops text editing', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toolbar-text')));
    await tester.pump();
    await tester.tapAt(const Offset(120, 200));
    await tester.pump();
    await tester.pump();

    final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    expect(model.editing, isTrue);
    expect(find.byType(TextBlockControls), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(model.editing, isFalse);
    expect(find.byType(TextBlockControls), findsNothing);
  });

  testWidgets('code blocks resize from the bottom-right handle', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await _placeCodeBlock(tester, const Offset(120, 100));
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
    await _placeCodeBlock(tester, const Offset(120, 100));

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

    await _placeCodeBlock(tester, const Offset(120, 100));
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

    await tester.tap(find.byKey(const ValueKey('toolbar-text')));
    await tester.pump();
    await tester.tapAt(const Offset(40, 520));
    await tester.pump();
    await tester.pump();
    await _placeCodeBlock(tester, const Offset(120, 100));
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

    await tester.tap(find.byKey(const ValueKey('toolbar-text')));
    await tester.pump();
    await tester.tapAt(const Offset(40, 520));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();
    await tester.dragFrom(
      const Offset(350, 540),
      const Offset(50, 20),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await _placeCodeBlock(tester, const Offset(120, 100));
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

    await tester.tap(find.byKey(const ValueKey('toolbar-text')));
    await tester.pump();
    await tester.tapAt(const Offset(40, 520));
    await tester.pump();
    await tester.pump();
    await _placeCodeBlock(tester, const Offset(120, 100));
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

    await tester.tap(find.byKey(const ValueKey('toolbar-text')));
    await tester.pump();
    await tester.tapAt(const Offset(40, 520));
    await tester.pump();
    await tester.pump();
    await _placeCodeBlock(tester, const Offset(120, 100));
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

    await tester.tap(find.byKey(const ValueKey('toolbar-text')));
    await tester.pump();
    await tester.tapAt(const Offset(40, 520));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toolbar-text')));
    await tester.pump();
    await tester.tapAt(const Offset(500, 520));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();
    await tester.dragFrom(
      const Offset(350, 540),
      const Offset(50, 20),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await _placeCodeBlock(tester, const Offset(120, 100));
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
    await _placeCodeBlock(tester, const Offset(120, 100));

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

  testWidgets('right drag pans instead of drawing in Draw mode', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();

    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    final rightDrag = await tester.startGesture(
      const Offset(300, 500),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await rightDrag.moveBy(const Offset(80, 60));
    await rightDrag.up();
    await tester.pump();

    expect(canvas.controller.offset, isNot(Offset.zero));
    expect(find.byType(PenStroke), findsNothing);
  });

  testWidgets('space temporarily hands dragging back to the canvas', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.byKey(const ValueKey('pen-preview')), findsOneWidget);
    await tester.dragFrom(const Offset(100, 200), const Offset(80, 40));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.byType(PenStroke), findsNothing);

    await tester.dragFrom(const Offset(100, 200), const Offset(80, 40));
    await tester.pump();
    expect(find.byType(PenStroke), findsOneWidget);
  });

  testWidgets('eraser scrubs every overlapping element and saves', (
    tester,
  ) async {
    PenElementData stroke(String id, Offset position) => PenElementData(
      id: id,
      position: position,
      size: const Size(100, 100),
      hitSlop: 6,
      color: 0xff000000,
      width: 3,
      points: const [
        PenPointData(Offset(0, 50), pressure: 0.5),
        PenPointData(Offset(100, 50), pressure: 0.5),
      ],
    );

    final document = CanvasDocument(
      background: CanvasBackgroundKind.plain,
      elements: [
        TextElementData(
          id: 'text-overlap',
          position: const Offset(100, 250),
          width: 280,
          height: 100,
          markdown: 'overlap',
          style: const TextNodeStyle(
            fontFamily: 'Source Serif 4',
            fontSize: 20,
            color: '#201C1A',
          ),
        ),
        CodeElementData(
          id: 'code-overlap',
          position: const Offset(100, 250),
          size: const Size(280, 240),
          language: CodeLanguage.dart,
          source: '',
        ),
        stroke('pen-overlap', const Offset(100, 250)),
        ArrowElementData(
          id: 'arrow-overlap',
          start: const Offset(100, 300),
          control: const Offset(150, 300),
          end: const Offset(200, 300),
        ),
        TextElementData(
          id: 'text-drag',
          position: const Offset(500, 250),
          width: 160,
          height: 100,
          markdown: 'drag',
          style: const TextNodeStyle(
            fontFamily: 'Source Serif 4',
            fontSize: 20,
            color: '#201C1A',
          ),
        ),
        stroke('pen-safe', const Offset(100, 450)),
      ],
    );
    await SharedPreferencesAsync().setString(
      CanvasDocumentStore.key,
      jsonEncode(document.toJson()),
    );
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('toolbar-draw')));
    await tester.tap(find.byKey(const ValueKey('toolbar-erase')));
    await tester.pump();
    final erase = await tester.startGesture(
      const Offset(150, 300),
      kind: PointerDeviceKind.mouse,
    );
    await erase.moveTo(const Offset(550, 300));
    await erase.up();
    await tester.pump();

    expect(find.byType(TextBlock), findsNothing);
    expect(find.byType(CodeBlock), findsNothing);
    expect(find.byType(Arrow), findsNothing);
    expect(find.byType(PenStroke), findsOneWidget);
    expect(
      tester.widget<PenStroke>(find.byType(PenStroke)).model.data.id,
      'pen-safe',
    );

    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    final pan = await tester.startGesture(
      const Offset(150, 500),
      kind: PointerDeviceKind.mouse,
    );
    await pan.moveBy(const Offset(40, 20));
    await pan.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(canvas.controller.offset, isNot(Offset.zero));
    expect(find.byType(PenStroke), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    final saved = CanvasDocument.fromJson(
      jsonDecode(
        (await SharedPreferencesAsync().getString(
          CanvasDocumentStore.key,
        ))!,
      ),
    );
    expect(saved.elements.map((element) => element.id), ['pen-safe']);
  });
}

Future<void> _placeCodeBlock(WidgetTester tester, Offset position) async {
  await tester.tap(find.byKey(const ValueKey('toolbar-code')));
  await tester.pump();
  await tester.tapAt(position);
  await tester.pump();
}
