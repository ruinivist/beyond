import 'package:flutter/material.dart';

import 'canvas/canvas_page.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadCodeFont();
  runApp(const PlaneApp());
}

class PlaneApp extends StatelessWidget {
  const PlaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: starlessLightThemeData,
      home: const CanvasPage(),
    );
  }
}
