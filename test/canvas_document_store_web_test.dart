@TestOn('browser')
library;

import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

void main() {
  setUp(() async {
    SharedPreferencesAsyncWeb.registerWith(null);
    await SharedPreferencesAsync().remove(CanvasDocumentStore.key);
  });

  test('persists the v3 canvas document in browser storage', () async {
    const document = CanvasDocument(
      background: CanvasBackgroundKind.plain,
      elements: [],
    );
    final store = CanvasDocumentStore();

    await store.save(document);

    expect((await store.load())?.toJson(), document.toJson());
  });
}
