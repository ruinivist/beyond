// Persists named canvases, folders, and the current file as one JSON library.
// Used by the canvas page's local save and file-switching flows.

import 'dart:convert';

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/persistence/canvas_library.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------- Persistence ----------

class CanvasDocumentStore {
  // ---------- Constants ----------

  static const libraryKey = 'beyond.canvas.library.v1';

  // ---------- State ----------

  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  CanvasLibrary library = CanvasLibrary.initial();

  // ---------- Public API ----------

  Future<CanvasDocument?> load() async {
    final savedLibrary = await _preferences.getString(libraryKey);
    library = savedLibrary == null ? CanvasLibrary.initial() : CanvasLibrary.fromJson(jsonDecode(savedLibrary));
    return savedLibrary == null ? null : library.current.document;
  }

  Future<void> save(CanvasDocument document) {
    return saveLibrary(library.replace(library.current.copyWith(document: document)));
  }

  Future<void> saveLibrary(CanvasLibrary next) async {
    // ponytail: one atomic library write; split documents out if library size makes saves slow.
    await _preferences.setString(libraryKey, jsonEncode(next.toJson()));
    library = next;
  }
}
