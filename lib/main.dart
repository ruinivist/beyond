import 'package:flutter/material.dart';

import 'canvas/canvas_page.dart';
import 'theme/starless_light.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadCodeFont();
  runApp(const BeyondApp());
}

class BeyondApp extends StatelessWidget {
  const BeyondApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: starlessLightThemeData,
      home: const CanvasPage(),
    );
  }
}
