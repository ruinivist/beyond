import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/canvas/canvas_clipboard.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/canvas_element_model.dart';
import 'package:beyond/canvas/canvas_page.dart';
import 'package:beyond/canvas/tools/arrow/arrow_tool.dart';
import 'package:beyond/canvas/tools/code_block/code_block.dart';
import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:beyond/canvas/tools/pen/pen_tool.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/theme/starless.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

void main() {
  setUp(() => SharedPreferencesAsyncWeb.registerWith(null));

  test(
    'clipboard payload round-trips and rejects recognized malformed data',
    () {
      final payload = encodeCanvasClipboard(_document.elements);
      expect(
        decodeCanvasClipboard(
          payload,
        )!.map((element) => element.toJson()),
        _document.elements.map((element) => element.toJson()),
      );
      expect(decodeCanvasClipboard('ordinary clipboard text'), isNull);
      expect(
        () => decodeCanvasClipboard(
          '{"format":"beyond-canvas-clipboard","version":1}',
        ),
        throwsFormatException,
      );
      expect(
        () => decodeCanvasClipboard(
          '{"format":"beyond-canvas-clipboard",',
        ),
        throwsFormatException,
      );
    },
  );

  test('clipboard preserves shape geometry', () {
    final shape = ShapeElementData(
      id: 'shape',
      kind: ShapeKind.diamond,
      position: const Offset(30, 40),
      size: const Size(120, 80),
    );

    final restored =
        decodeCanvasClipboard(
              encodeCanvasClipboard([shape]),
            )!.single
            as ShapeElementData;
    expect(restored.toJson(), shape.toJson());
  });

  testWidgets('copies, pastes, cuts, restores, and persists mixed elements', (
    tester,
  ) async {
    final store = _DocumentStore(_document);
    String? clipboard;
    var failWrite = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: CanvasPage(
          documentStore: store,
          readClipboardText: () async => clipboard,
          writeClipboardText: (text) async {
            if (failWrite) throw StateError('write failed');
            clipboard = text;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    for (final model in _models(tester)) {
      model.selected = true;
    }
    await _shortcut(tester, LogicalKeyboardKey.keyC);
    expect(clipboard, isNotNull);

    await _shortcut(tester, LogicalKeyboardKey.keyV);
    await _waitForSave(tester);
    final copied = store.persisted!;
    expect(copied.elements, hasLength(8));
    expect(_types(copied.elements), [
      ..._types(_document.elements),
      ..._types(_document.elements),
    ]);
    expect(copied.elements.map((element) => element.id).toSet(), hasLength(8));
    final firstPaste = copied.elements
        .skip(4)
        .map((element) => element.copy())
        .toList();
    for (var index = 0; index < 4; index++) {
      _expectShifted(
        _document.elements[index],
        firstPaste[index],
        const Offset(24, 24),
      );
    }
    _expectOnlySelected(
      tester,
      firstPaste.map((element) => element.id).toSet(),
    );

    failWrite = true;
    await _shortcut(tester, LogicalKeyboardKey.keyX);
    await tester.pump();
    expect(_models(tester), hasLength(8));
    expect(find.text('Could not cut canvas elements'), findsOneWidget);

    failWrite = false;
    await _shortcut(tester, LogicalKeyboardKey.keyX);
    await _waitForSave(tester);
    expect(store.persisted!.elements, hasLength(4));

    await _shortcut(tester, LogicalKeyboardKey.keyV);
    await _waitForSave(tester);
    final restored = store.persisted!;
    expect(restored.elements, hasLength(8));
    final restoredPaste = restored.elements.skip(4).toList();
    expect(
      restoredPaste
          .map((element) => element.id)
          .toSet()
          .intersection(
            firstPaste.map((element) => element.id).toSet(),
          ),
      isEmpty,
    );
    for (var index = 0; index < 4; index++) {
      _expectShifted(firstPaste[index], restoredPaste[index], Offset.zero);
    }
    _expectOnlySelected(
      tester,
      restoredPaste.map((element) => element.id).toSet(),
    );

    await _shortcut(tester, LogicalKeyboardKey.keyV);
    await _waitForSave(tester);
    final cascaded = store.persisted!;
    expect(cascaded.elements, hasLength(12));
    for (var index = 0; index < 4; index++) {
      _expectShifted(
        firstPaste[index],
        cascaded.elements[index + 8],
        const Offset(24, 24),
      );
    }
    _expectOnlySelected(
      tester,
      cascaded.elements.skip(8).map((element) => element.id).toSet(),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(const Offset(300, 400));
    await _shortcut(tester, LogicalKeyboardKey.keyC);

    const target = Offset(600, 400);
    await mouse.moveTo(target);
    await _shortcut(tester, LogicalKeyboardKey.keyV);
    await _waitForSave(tester);
    final controller = tester
        .widget<LazyCanvas>(find.byType(LazyCanvas))
        .controller;
    final targetOnCanvas = controller.offset + target / controller.scale;
    expect(_selectedBounds(tester).center, targetOnCanvas);

    await _shortcut(tester, LogicalKeyboardKey.keyV);
    await _waitForSave(tester);
    expect(
      _selectedBounds(tester).center,
      targetOnCanvas + const Offset(24, 24) / controller.scale,
    );

    clipboard = encodeCanvasClipboard(
      _document.elements.map(
        (element) => element.copy(id: 'external-${element.id}'),
      ),
    );
    await _shortcut(tester, LogicalKeyboardKey.keyV);
    await _waitForSave(tester);
    expect(_selectedBounds(tester).center, targetOnCanvas);
    await mouse.removePointer();
  });
}

Future<void> _shortcut(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<void> _waitForSave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 320));
  await tester.pump();
}

List<CanvasElementModel> _models(WidgetTester tester) => <CanvasElementModel>[
  ...tester
      .widgetList<TextBlock>(find.byType(TextBlock))
      .map((widget) => widget.model),
  ...tester
      .widgetList<CodeBlock>(find.byType(CodeBlock))
      .map((widget) => widget.model),
  ...tester
      .widgetList<PenStroke>(find.byType(PenStroke))
      .map((widget) => widget.model),
  ...tester.widgetList<Arrow>(find.byType(Arrow)).map((widget) => widget.model),
];

void _expectOnlySelected(WidgetTester tester, Set<String> ids) {
  for (final model in _models(tester)) {
    expect(model.selected, ids.contains(model.data.id), reason: model.data.id);
  }
}

List<String> _types(Iterable<CanvasElementData> elements) =>
    elements.map((element) => element.type).toList();

Rect _selectedBounds(WidgetTester tester) => _models(tester)
    .where((model) => model.selected)
    .map((model) => model.canvasPosition & model.canvasSize)
    .reduce((bounds, next) => bounds.expandToInclude(next));

void _expectShifted(
  CanvasElementData source,
  CanvasElementData result,
  Offset delta,
) {
  expect(result.type, source.type);
  switch ((source, result)) {
    case (final TextElementData source, final TextElementData result):
      expect(result.position, source.position + delta);
      expect(result.markdown, source.markdown);
      expect(result.style.toJson(), source.style.toJson());
    case (final CodeElementData source, final CodeElementData result):
      expect(result.position, source.position + delta);
      expect(result.source, source.source);
      expect(result.language, source.language);
    case (final PenElementData source, final PenElementData result):
      expect(result.position, source.position + delta);
      expect(result.toJson()['points'], source.toJson()['points']);
      expect(result.color, source.color);
      expect(result.width, source.width);
    case (final ArrowElementData source, final ArrowElementData result):
      expect(result.start, source.start + delta);
      expect(result.control, source.control + delta);
      expect(result.end, source.end + delta);
    default:
      fail('Mismatched element types');
  }
}

final _document = CanvasDocument(
  background: CanvasBackgroundKind.plain,
  elements: [
    TextElementData(
      id: 'text',
      position: const Offset(10, 20),
      width: 280,
      height: null,
      markdown: 'hello',
      style: const TextNodeStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        color: '#201C1A',
      ),
    ),
    CodeElementData(
      id: 'code',
      position: const Offset(40, 50),
      size: const Size(280, 240),
      language: CodeLanguage.dart,
      source: 'void main() {}',
    ),
    PenElementData(
      id: 'pen',
      position: const Offset(70, 80),
      size: const Size(10, 10),
      hitSlop: 0,
      color: 0xff000000,
      width: 1,
      points: const [PenPointData(Offset.zero, pressure: 0)],
    ),
    ArrowElementData(
      id: 'arrow',
      start: const Offset(100, 110),
      control: const Offset(110, 114),
      end: const Offset(120, 110),
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
