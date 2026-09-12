// Persists and restores the current canvas document as JSON.
// Used by the canvas page's local save and startup flows.

import 'dart:convert';

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------- Persistence ----------

class CanvasDocumentStore {
  // ---------- Constants ----------

  static const key = 'beyond.canvas.document.v3';

  // ---------- State ----------

  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  // ---------- Public API ----------

  Future<CanvasDocument?> load() async {
    final source = await _preferences.getString(key);
    if (source == null) return null;
    return CanvasDocument.fromJson(jsonDecode(source));
  }

  Future<void> save(CanvasDocument document) {
    return _preferences.setString(key, jsonEncode(document.toJson()));
  }
}
