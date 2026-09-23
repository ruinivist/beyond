// Checks file creation, naming, switching, and persistence failure behavior.
// Exercises the file picker through the canvas title and browser-backed UI.

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_background.dart';
import 'package:beyond/canvas/editor/widgets/canvas_file_picker.dart';
import 'package:beyond/canvas/editor/widgets/canvas_title.dart';
import 'package:beyond/canvas/persistence/canvas_library.dart';
import 'package:beyond/canvas/tools/text/text_tool.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

import '../test_helpers.dart';

// ---------- Tests ----------

void main() {
  setUp(() => SharedPreferencesAsyncWeb.registerWith(null));

  testWidgets('creates nested canvases, renames, switches, and isolates undo', (tester) async {
    final store = TestCanvasDocumentStore(
      CanvasDocument(
        background: CanvasBackgroundKind.plain,
        elements: [
          TextElementData(
            id: 'original-text',
            position: const Offset(100, 150),
            width: 280,
            height: null,
            markdown: 'Original contents',
            style: const TextNodeStyle(fontFamily: 'Inter', color: '#201C1A'),
          ),
        ],
      ),
    );
    await pumpCanvas(tester, store);
    final originalId = store.library.currentId;
    tester.widget<TextTool>(find.byType(TextTool)).model.insertPastedText(' edited');
    await _open(tester);
    expect(store.library.current.document!.elements.whereType<TextElementData>().single.markdown, contains('edited'));

    await tester.tap(find.byTooltip('New folder'));
    await _name(tester, 'Notes');
    final folder = store.library.files.singleWhere((file) => file.isFolder);
    await tester.tap(find.text('Notes'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New canvas'));
    await _name(tester, 'Brainstorm');
    expect(find.byType(CanvasFilePicker), findsNothing);
    expect(find.byType(TextTool), findsNothing);
    expect(store.library.current.parentId, folder.id);
    expect(tester.widget<CanvasTitle>(find.byType(CanvasTitle)).path, ['Notes', 'Brainstorm']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.byType(TextTool), findsNothing);

    await _open(tester);
    final canvasId = store.library.currentId;
    await tester.tap(find.byKey(ValueKey('file-tree-node-$canvasId')), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await _name(tester, 'Ideas');
    expect(store.library.current.name, 'Ideas');
    await tester.tap(find.byKey(ValueKey('file-tree-node-$originalId')));
    await tester.pumpAndSettle();
    expect(store.library.currentId, originalId);
    expect(tester.widget<TextTool>(find.byType(TextTool)).model.node.markdown, contains('edited'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects duplicate names, cancels drafts, and retains failed changes', (tester) async {
    final store = _FailingLibraryStore();
    await pumpCanvas(tester, store);
    await _open(tester);
    await tester.tap(find.byTooltip('New canvas'));
    await _name(tester, 'Untitled');
    expect(find.text('This name is already in use'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(CanvasFilePicker), findsOneWidget);
    expect(store.library.files, hasLength(1));

    store.fail = true;
    await tester.tap(find.byTooltip('New folder'));
    await _name(tester, 'Unsaved');
    expect(find.text('Could not save changes. Please try again.'), findsOneWidget);
    expect(store.library.files, hasLength(1));
    expect(find.byType(TextField), findsOneWidget);
    store.fail = false;
    await _name(tester, 'Saved');
    expect(store.library.files, hasLength(2));
    await tester.tap(find.text('Saved'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.library.files, hasLength(2));
    await tester.tap(find.text('Saved'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.library.files, hasLength(1));
    final previousId = store.library.currentId;
    await tester.tap(find.text('Untitled').last, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(CanvasFilePicker), findsNothing);
    expect(store.library.currentId, isNot(previousId));
    expect(store.library.current.document!.elements, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

// ---------- Helpers ----------

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byType(CanvasTitle));
  await tester.pumpAndSettle();
}

Future<void> _name(WidgetTester tester, String value) async {
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), value);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

class _FailingLibraryStore extends TestCanvasDocumentStore {
  bool fail = false;

  @override
  Future<void> saveLibrary(CanvasLibrary next) async {
    if (fail) throw StateError('Storage full');
    await super.saveLibrary(next);
  }
}
