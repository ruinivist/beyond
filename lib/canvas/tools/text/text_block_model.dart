// Owns editable text element state and persistence synchronization.
// Used by text rendering, editing, transformation, and document storage.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_element_model.dart';
import 'package:beyond/canvas/persistence/attachments/store.dart';
import 'package:flutter/material.dart';
import 'package:scroll_animator/scroll_animator.dart';
import 'package:uuid/uuid.dart';

// ---------- Models ----------

/// Owns controllers and mutable state for a persisted text element.
/// Used by the text tool, Markdown surfaces, controls, and persistence.
class TextBlockModel extends CanvasElementModel<TextElementData> {
  // ---------- Construction ----------

  TextBlockModel(TextElementData data) : super(data) {
    controller = TextEditingController(text: data.markdown);
    controller.addListener(_syncMarkdown);
  }

  // ---------- State and geometry ----------

  TextElementData get node => data;
  late final TextEditingController controller;
  final FocusNode focusNode = FocusNode();
  final scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );
  final layerLink = LayerLink();
  bool _editing = false;

  @override
  Offset get canvasPosition => data.position;

  @override
  Size get canvasSize => Size(data.width, data.height ?? textNodeMinimumHeight);

  @override
  void moveBy(Offset delta) {
    if (delta == Offset.zero) return;
    data.position += delta;
    notifyListeners();
  }

  bool get editing => _editing;

  set editing(bool value) {
    if (_editing == value) return;
    _editing = value;
    notifyListeners();
  }

  TextNodeStyle get style => node.style;

  set style(TextNodeStyle value) {
    if (_sameStyle(node.style, value)) return;
    node.style = value;
    notifyListeners();
  }

  void resize(Size renderedSize, Offset delta) {
    final width = math.max(textNodeMinimumWidth, node.width + delta.dx);
    final height = math.max(
      textNodeMinimumHeight,
      (node.height ?? renderedSize.height) + delta.dy,
    );
    if (node.width == width && node.height == height) return;
    node
      ..width = width
      ..height = height;
    notifyListeners();
  }

  void rotate(double angle) {
    if (node.rotation == angle) return;
    node.rotation = angle;
    notifyListeners();
  }

  // ---------- Content insertion ----------

  Future<void> insertPastedImage(
    Uint8List bytes,
    String extension,
    AttachmentStore store,
  ) async {
    if (bytes.length > attachmentMaximumBytes) {
      throw const FormatException('Image exceeds 10 MiB');
    }
    final path = 'attachments/${const Uuid().v4()}.$extension';
    await store.write(path, bytes);
    _insertText('![pasted image]($path)');
  }

  void insertPastedText(String text) => _insertText(text);

  // ---------- Private helpers ----------

  void _insertText(String text) {
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    final from = math.min(start, end).clamp(0, controller.text.length);
    final to = math.max(start, end).clamp(0, controller.text.length);
    controller.value = TextEditingValue(
      text: controller.text.replaceRange(from, to, text),
      selection: TextSelection.collapsed(offset: from + text.length),
    );
  }

  void _syncMarkdown() {
    if (node.markdown == controller.text) return;
    node.markdown = controller.text;
    notifyListeners();
  }

  // ---------- Lifecycle ----------

  @override
  void dispose() {
    controller
      ..removeListener(_syncMarkdown)
      ..dispose();
    focusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }
}

// ---------- Helpers ----------

bool _sameStyle(TextNodeStyle first, TextNodeStyle second) {
  return first.fontFamily == second.fontFamily && first.fontSize == second.fontSize && first.color == second.color;
}
