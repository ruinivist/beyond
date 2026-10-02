// Boots the Beyond application and owns its root theme state.
// Used as the Flutter entry point for the canvas editor.

import 'package:beyond/canvas/editor/canvas_page.dart';
import 'package:beyond/canvas/persistence/attachments/store.dart';
import 'package:beyond/canvas/persistence/canvas_document_store.dart';
import 'package:beyond/canvas/persistence/canvas_project_files.dart';
import 'package:beyond/theme/starless.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------- Theme preference ----------

const themePreferenceKey = 'beyond.theme.mode';

Future<ThemeMode> loadThemeMode(SharedPreferencesAsync preferences) async {
  try {
    return await preferences.getString(themePreferenceKey) == 'dark' ? ThemeMode.dark : ThemeMode.light;
  } on Object {
    return ThemeMode.light;
  }
}

// ---------- Application bootstrap ----------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  // TODO(dev): bundle it instead of fetching fonts at runtime.
  await loadFonts();
  final preferences = SharedPreferencesAsync();
  runApp(BeyondApp(initialThemeMode: await loadThemeMode(preferences), preferences: preferences));
}

// ---------- Root application ----------

/// Hosts the canvas editor under the application theme.
/// Used as the root widget created by the application bootstrap.
class BeyondApp extends StatefulWidget {
  const BeyondApp({
    this.initialThemeMode = ThemeMode.light,
    this.preferences,
    this.attachmentStore,
    this.documentStore,
    this.projectFiles,
    super.key,
  });

  final ThemeMode initialThemeMode;
  final SharedPreferencesAsync? preferences;
  final AttachmentStore? attachmentStore;
  final CanvasDocumentStore? documentStore;
  final CanvasProjectFiles? projectFiles;

  @override
  State<BeyondApp> createState() => _BeyondAppState();
}

class _BeyondAppState extends State<BeyondApp> {
  // ---------- State and persistence ----------

  late ThemeMode _themeMode = widget.initialThemeMode;
  late final SharedPreferencesAsync _preferences = widget.preferences ?? SharedPreferencesAsync();
  Future<void> _saveQueue = Future<void>.value();

  Future<void> _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    final save = _saveQueue.then((_) => _preferences.setString(themePreferenceKey, mode.name));
    _saveQueue = save.catchError((Object _) {});
    return save;
  }

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: starlessLightThemeData,
      darkTheme: starlessDarkThemeData,
      themeMode: _themeMode,
      home: CanvasPage(
        attachmentStore: widget.attachmentStore,
        documentStore: widget.documentStore,
        projectFiles: widget.projectFiles,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}
