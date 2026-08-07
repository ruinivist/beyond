import 'package:flutter/material.dart';

import 'canvas_page.dart';

void main() => runApp(const PlaneApp());

class PlaneApp extends StatelessWidget {
  const PlaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
      home: const CanvasPage(),
    );
  }
}
