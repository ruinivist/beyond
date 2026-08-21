import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/canvas_page.dart';
import 'package:beyond/theme/starless_light.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  await loadCodeFont();
  runApp(const BeyondApp());
}

class BeyondApp extends StatelessWidget {
  const BeyondApp({this.attachmentStore, super.key});

  final AttachmentStore? attachmentStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: starlessLightThemeData,
      home: CanvasPage(attachmentStore: attachmentStore),
    );
  }
}
