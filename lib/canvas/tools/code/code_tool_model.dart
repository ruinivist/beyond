// Owns code editor state, geometry, language, and data synchronization.
// Used by the code tool renderer and canvas persistence flow.

part of 'code_tool.dart';

// ---------- Models ----------

/// Owns code editor controllers and keeps them synchronized with element data.
/// Used by code block rendering and canvas persistence.
class CodeBlockModel extends CanvasElementModel<CodeElementData> {
  // ---------- Construction ----------

  CodeBlockModel(CodeElementData data) : super(data) {
    controller.text = data.source;
    controller.addListener(_syncSource);
  }

  final controller = CodeLineEditingController(
    options: const CodeLineOptions(indentSize: 4),
  );
  final focusNode = FocusNode();
  final scrollController = CodeScrollController(
    verticalScroller: AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    ),
    horizontalScroller: AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
    ),
  );

  // ---------- Geometry and language ----------

  @override
  Offset get canvasPosition => data.position;

  @override
  Size get canvasSize => data.size;

  Size get size => data.size;

  set size(Size value) {
    final nextSize = _clampSize(value);
    if (data.size == nextSize) return;
    data.size = nextSize;
    notifyListeners();
  }

  CodeLanguage get language => data.language;

  set language(CodeLanguage value) {
    if (data.language == value) return;
    data.language = value;
    notifyListeners();
  }

  @override
  void moveBy(Offset delta) {
    if (delta == Offset.zero) return;
    data.position += delta;
    notifyListeners();
  }

  // ---------- Synchronization ----------

  void _syncSource() {
    if (data.source == controller.text) return;
    data.source = controller.text;
    notifyListeners();
  }

  // ---------- Lifecycle ----------

  @override
  void dispose() {
    controller
      ..removeListener(_syncSource)
      ..dispose();
    focusNode.dispose();
    scrollController
      ..verticalScroller.dispose()
      ..horizontalScroller.dispose()
      ..dispose();
    super.dispose();
  }
}

// ---------- Geometry ----------

Size _clampSize(Size size) {
  return Size(
    math.max(codeBlockMinimumSize.width, size.width),
    math.max(codeBlockMinimumSize.height, size.height),
  );
}
