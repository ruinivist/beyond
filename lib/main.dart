import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/canvas_page.dart';
import 'package:beyond/canvas/canvas_project_files.dart';
import 'package:beyond/theme/starless_light.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  // TODO(dev): bundle it instead of fetching fonts at runtime.
  await loadFonts();
  runApp(const BeyondApp());
}

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
