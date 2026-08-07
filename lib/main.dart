import 'package:flutter/material.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';

void main() => runApp(
  MaterialApp(
    home: LazyCanvas(controller: LazyCanvasController(debug: true)),
  ),
);
