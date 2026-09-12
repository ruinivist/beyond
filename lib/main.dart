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

// ---------- Application bootstrap ----------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  // TODO(dev): bundle it instead of fetching fonts at runtime.
  await loadFonts();
  runApp(const BeyondApp());
}

// ---------- Root application ----------

/// Hosts the canvas editor under the application theme.
/// Used as the root widget created by the application bootstrap.
class BeyondApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: starlessLightThemeData,
      home: CanvasPage(
        attachmentStore: attachmentStore,
        documentStore: documentStore,
        projectFiles: projectFiles,
      ),
    );
  }
}
