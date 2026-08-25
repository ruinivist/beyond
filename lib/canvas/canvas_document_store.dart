import 'dart:convert';

import 'package:beyond/canvas/canvas_document.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CanvasDocumentStore {
  static const key = 'beyond.canvas.document.v2';

  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<CanvasDocument?> load() async {
    final source = await _preferences.getString(key);
    if (source == null) return null;
    return CanvasDocument.fromJson(jsonDecode(source));
  }

  Future<void> save(CanvasDocument document) {
    return _preferences.setString(key, jsonEncode(document.toJson()));
  }
}
