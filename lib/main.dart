// Boots the Beyond application and owns its root theme state.
// Used as the Flutter entry point for the canvas editor.

import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/canvas_page.dart';
import 'package:beyond/canvas/canvas_project_files.dart';
import 'package:beyond/theme/starless.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------- Application bootstrap ----------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  // TODO(dev): bundle it instead of fetching fonts at runtime.
  await loadFonts();
  runApp(const BeyondApp());
}

// ---------- Root application ----------

/// Hosts the canvas editor and the currently selected application theme.
/// Used as the root widget created by the application bootstrap.
class BeyondApp extends StatefulWidget {
  const BeyondApp({
    this.attachmentStore,
    this.documentStore,
    this.projectFiles,
    super.key,
  });

  final AttachmentStore? attachmentStore;
  final CanvasDocumentStore? documentStore;
  final CanvasProjectFiles? projectFiles;

  @override
  State<BeyondApp> createState() => _BeyondAppState();
}

class _BeyondAppState extends State<BeyondApp> {
  // ---------- State ----------

  AppTheme _theme = AppTheme.starlessLight;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme.themeData,
      home: CanvasPage(
        appTheme: _theme,
        attachmentStore: widget.attachmentStore,
        documentStore: widget.documentStore,
        onAppThemeChanged: (theme) => setState(() => _theme = theme),
        projectFiles: widget.projectFiles,
      ),
    );
  }
}
