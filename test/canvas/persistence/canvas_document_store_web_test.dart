// Verifies browser persistence for the current canvas document.
// Exercises the document store with web shared preferences.

@TestOn('browser')
library;

import 'dart:convert';

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_background.dart';
import 'package:beyond/canvas/persistence/canvas_document_store.dart';
import 'package:beyond/canvas/persistence/canvas_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

// ---------- Tests ----------

void main() {
  setUp(() async {
    SharedPreferencesAsyncWeb.registerWith(null);
    await SharedPreferencesAsync().remove(CanvasDocumentStore.key);
    await SharedPreferencesAsync().remove(CanvasDocumentStore.libraryKey);
  });

  test('persists the current canvas document in browser storage', () async {
    const document = CanvasDocument(
      background: CanvasBackgroundKind.plain,
      elements: [],
    );
    final store = CanvasDocumentStore();

    await store.save(document);

    expect((await store.load())?.toJson(), document.toJson());
  });

  test('retains the old canvas and restores folders and the selected file', () async {
    const original = CanvasDocument(background: CanvasBackgroundKind.plain, elements: []);
    await SharedPreferencesAsync().setString(CanvasDocumentStore.key, jsonEncode(original.toJson()));
    final store = CanvasDocumentStore();
    await store.load();
    final originalId = store.library.currentId;
    final next = CanvasLibrary(
      currentId: 'second',
      files: [
        store.library.current,
        const CanvasFile(id: 'folder', name: 'Notes'),
        const CanvasFile(id: 'second', name: 'Ideas', parentId: 'folder', document: CanvasLibrary.emptyDocument),
      ],
    );
    await store.saveLibrary(next);
    final restored = CanvasDocumentStore();
    expect((await restored.load())!.background, CanvasBackgroundKind.dotGrid);
    expect(restored.library.path('second').map((file) => file.name), ['Notes', 'Ideas']);
    expect(restored.library.file(originalId).document!.toJson(), original.toJson());
    expect(restored.library.currentId, 'second');
    expect(
      () => CanvasLibrary.fromJson({
        ...next.toJson(),
        'files': [const CanvasFile(id: 'folder', name: 'Cycle', parentId: 'folder').toJson()],
      }),
      throwsFormatException,
    );
  });
}
