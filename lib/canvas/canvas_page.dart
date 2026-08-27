import 'dart:async';
import 'dart:math' as math;

import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/canvas/canvas_clipboard.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/canvas_element_model.dart';
import 'package:beyond/canvas/canvas_project.dart';
import 'package:beyond/canvas/canvas_project_files.dart';
import 'package:beyond/canvas/tools/arrow/arrow_tool.dart';
import 'package:beyond/canvas/tools/code_block/code_block.dart';
import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:beyond/canvas/tools/pen/pen_tool.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/foundation/button.dart';
import 'package:beyond/foundation/control_surface.dart';
import 'package:beyond/foundation/discrete_slider.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/utils/preset_colors.dart';
import 'package:beyond/widgets/settings_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:scribble/scribble.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:uuid/uuid.dart';

enum _CanvasTool { select, text, pen, arrow, eraser }

class CanvasPage extends StatefulWidget {
  const CanvasPage({
    this.attachmentStore,
    this.documentStore,
    this.projectFiles,
    this.readClipboardText,
    this.writeClipboardText,
    super.key,
  });

  final AttachmentStore? attachmentStore;
  final CanvasDocumentStore? documentStore;
  final CanvasProjectFiles? projectFiles;
  final Future<String?> Function()? readClipboardText;
  final Future<void> Function(String text)? writeClipboardText;

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final _canvasController = LazyCanvasController(
    buildCacheExtent: const Offset(600, 400),
    useIdsFromArgs: true,
  );
  CanvasBackgroundKind _canvasBackgroundKind = CanvasBackgroundKind.dotGrid;
  late final CanvasDocumentStore _documentStore =
      widget.documentStore ?? CanvasDocumentStore();
  late final AttachmentStore _attachmentStore =
      widget.attachmentStore ?? createAttachmentStore();
  late final CanvasProjectFiles _projectFiles =
      widget.projectFiles ?? createCanvasProjectFiles();
  final _elements = <CanvasElementModel>[];
  TextBlockModel? _editingTextBlock;
  TextBlockModel? _editingChromeModel;
  final ValueNotifier<bool> _selectionModifierPressed = ValueNotifier(false);
  final _interactiveCanvasPointerIds = <int>{};
  final _selectionBeforeWidgetPointer = <Object>{};
  final _selectionKeys = <Object, GlobalKey>{};
  final _selectionBeforeDrag = <Object>{};
  int? _widgetPointer;
  int? _dragSelectionPointer;
  Offset? _dragSelectionStart;
  Offset? _dragSelectionEnd;
  int? _dragArrowPointer;
  ArrowModel? _dragArrow;
  var _toggleDragSelection = false;
  Timer? _saveTimer;
  Future<void> _saveQueue = Future<void>.value();
  bool _documentDirty = false;
  bool _documentLoaded = false;
  var _projectTransferActive = false;
  late final PenTool _penTool;
  late final ArrowTool _arrowTool;
  Color _penColor = presetColors.first.color;
  double _penWidth = 4;
  final ValueNotifier<_CanvasTool> _activeTool = ValueNotifier(
    _CanvasTool.select,
  );
  int? _eraserPointer;
  var _spaceHeld = false;
  ClipboardEvents? _clipboardEvents;
  String? _lastPastedPayload;
  String? _cutPayload;
  Offset _pasteOffset = Offset.zero;
  Offset? _canvasPointerPosition;
  (String, Offset?)? _pointerReference;

  bool get _penEnabled => _activeTool.value == _CanvasTool.pen;

  bool get _arrowEnabled => _activeTool.value == _CanvasTool.arrow;

  bool get _textPlacementEnabled => _activeTool.value == _CanvasTool.text;

  bool get _eraserEnabled => _activeTool.value == _CanvasTool.eraser;

  @override
  void initState() {
    super.initState();
    _penTool = PenTool(onStroke: _addStroke)
      ..setColor(_penColor)
      ..setStrokeWidth(_penWidth);
    _arrowTool = ArrowTool(onArrow: _addArrow)
      ..addListener(_handleArrowToolChanged);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _clipboardEvents =
        widget.readClipboardText == null && widget.writeClipboardText == null
        ? ClipboardEvents.instance
        : null;
    _clipboardEvents
      ?..registerCopyEventListener(_handleWebCopy)
      ..registerCutEventListener(_handleWebCut)
      ..registerPasteEventListener(_handleWebPaste);
    unawaited(_restoreDocument());
  }

  void _handleArrowToolChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colors = BTheme.of(context).colors;
    _canvasController.background = _canvasBackgroundKind.build(colors);
  }

  Offset _viewportCenter() {
    final viewport = _canvasController.canvasSize;
    return _canvasController.offset +
        Offset(viewport.width, viewport.height) / (2 * _canvasController.scale);
  }

  void _toggleTool(_CanvasTool tool) {
    if (!_documentLoaded) return;
    final enabling = _activeTool.value != tool;
    if (enabling) _clearTextEditing();
    setState(() {
      _activeTool.value = enabling ? tool : _CanvasTool.select;
      _eraserPointer = null;
      _spaceHeld = false;
    });
    if (enabling) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _setPenColor(Color color) {
    setState(() => _penColor = color);
    _penTool.setColor(color);
  }

  void _setPenWidth(double width) {
    setState(() => _penWidth = width);
    _penTool.setStrokeWidth(width);
  }

  void _handleCanvasPointerDown(PointerDownEvent event) {
    if (!_documentLoaded) return;
    if (_eraserEnabled && !_spaceHeld) {
      if (_eraserPointer == null &&
          (event.kind != PointerDeviceKind.mouse ||
              event.buttons == kPrimaryButton)) {
        _eraserPointer = event.pointer;
        _eraseAt(event.position);
      }
      return;
    }
    if (_penEnabled && !_spaceHeld) {
      _penTool.onPointerDown(event);
      return;
    }
    if (event.buttons != kPrimaryButton) return;
    final onInteractiveChild = _interactiveCanvasPointerIds.remove(
      event.pointer,
    );
    if (_textPlacementEnabled) {
      setState(() => _activeTool.value = _CanvasTool.select);
      _addTextBlock(
        _canvasController.offset +
            event.localPosition / _canvasController.scale,
      );
      return;
    }
    if (onInteractiveChild) {
      if (!_selectionModifierPressed.value) {
        _selectionBeforeWidgetPointer
          ..clear()
          ..addAll(_selectedModels());
        _widgetPointer = event.pointer;
        _clearSelection();
      }
      return;
    }
    if (_arrowEnabled) {
      _arrowTool.onPointerDown(
        event,
        _canvasController.offset +
            event.localPosition / _canvasController.scale,
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _clearTextEditing();
    _selectionBeforeDrag
      ..clear()
      ..addAll(_selectedModels());
    _toggleDragSelection = _selectionModifierPressed.value;
    if (!_toggleDragSelection) _clearSelection();
    if (event.kind != PointerDeviceKind.mouse ||
        _penEnabled ||
        _eraserEnabled) {
      return;
    }
    setState(() {
      _dragSelectionPointer = event.pointer;
      _dragSelectionStart = event.localPosition;
      _dragSelectionEnd = event.localPosition;
    });
  }

  void _handleCanvasPointerMove(PointerMoveEvent event) {
    if (_penEnabled) {
      _penTool.onPointerUpdate(event);
      return;
    }
    if (event.pointer == _eraserPointer) {
      _eraseAt(event.position);
      return;
    }
    if (_arrowTool.ownsPointer(event.pointer)) {
      _arrowTool.onPointerMove(
        event,
        _canvasController.offset +
            event.localPosition / _canvasController.scale,
      );
      return;
    }
    if (event.pointer == _dragArrowPointer) {
      final arrow = _dragArrow;
      if (arrow != null) _moveSelectedChildren(arrow, event.delta);
      return;
    }
    if (event.pointer != _dragSelectionPointer) return;
    _updateDragSelection(event.localPosition);
  }

  void _handleCanvasPointerUp(PointerUpEvent event) {
    if (_penEnabled) {
      _penTool.onPointerUp(event);
      return;
    }
    if (event.pointer == _eraserPointer) {
      _eraserPointer = null;
      return;
    }
    _finishWidgetPointer(event.pointer);
    if (_arrowTool.ownsPointer(event.pointer)) {
      _arrowTool.onPointerUp(
        event,
        _canvasController.offset +
            event.localPosition / _canvasController.scale,
      );
      return;
    }
    if (event.pointer == _dragArrowPointer) {
      _finishArrowDrag(select: true);
      return;
    }
    if (event.pointer != _dragSelectionPointer) return;
    _updateDragSelection(event.localPosition);
    _finishDragSelection();
  }

  void _handleCanvasPointerCancel(PointerCancelEvent event) {
    if (_penEnabled) {
      _penTool.onPointerCancel(event);
      return;
    }
    if (event.pointer == _eraserPointer) {
      _eraserPointer = null;
      return;
    }
    _finishWidgetPointer(event.pointer);
    if (_arrowTool.ownsPointer(event.pointer)) {
      _arrowTool.onPointerCancel(event);
      return;
    }
    if (event.pointer == _dragArrowPointer) {
      _finishArrowDrag();
      return;
    }
    if (event.pointer != _dragSelectionPointer) return;
    for (final model in _elements) {
      model.selected = _selectionBeforeDrag.contains(model);
    }
    _finishDragSelection();
  }

  void _updateDragSelection(Offset end) {
    final start = _dragSelectionStart;
    if (start == null) return;
    setState(() => _dragSelectionEnd = end);
    final rect = Rect.fromPoints(start, end);
    final positions = {
      for (final child in _canvasController.widgetsWithScreenPositions())
        child.id: child.ssPosition,
    };

    bool selected(CanvasElementModel model) {
      final id = model.data.id;
      final position = positions[id];
      final renderObject = _selectionKey(
        model,
      ).currentContext?.findRenderObject();
      final overlaps =
          position != null &&
          renderObject is RenderBox &&
          rect.overlaps(
            position & (renderObject.size * _canvasController.scale),
          );
      return _toggleDragSelection
          ? _selectionBeforeDrag.contains(model) != overlaps
          : overlaps;
    }

    for (final model in _elements) {
      model.selected = selected(model);
    }
  }

  void _finishDragSelection() {
    setState(() {
      _dragSelectionPointer = null;
      _dragSelectionStart = null;
      _dragSelectionEnd = null;
      _selectionBeforeDrag.clear();
    });
  }

  void _finishWidgetPointer(int pointer) {
    if (pointer != _widgetPointer) return;
    _widgetPointer = null;
    _selectionBeforeWidgetPointer.clear();
  }

  void _handleCodeBlockPointerDown(
    CodeBlockModel model,
    PointerDownEvent event,
  ) {
    if (event.buttons != kPrimaryButton ||
        !_documentLoaded ||
        _textPlacementEnabled ||
        _penEnabled ||
        _eraserEnabled) {
      return;
    }
    _interactiveCanvasPointerIds.add(event.pointer);
    if (!_elements.contains(model)) return;
    if (_selectionModifierPressed.value) {
      model.selected = !model.selected;
      return;
    }
    _clearTextEditing();
    _bringElementToFront(model);
  }

  void _handleTextBlockPointerDown(
    TextBlockModel model,
    PointerDownEvent event,
  ) {
    if (event.buttons != kPrimaryButton ||
        _textPlacementEnabled ||
        _penEnabled ||
        _eraserEnabled) {
      return;
    }
    _interactiveCanvasPointerIds.add(event.pointer);
    if (!_elements.contains(model)) return;
    if (_selectionModifierPressed.value) {
      model.selected = !model.selected;
      return;
    }
    if (!model.editing) {
      FocusManager.instance.primaryFocus?.unfocus();
      _clearTextEditing();
    }
    _bringElementToFront(model);
  }

  void _editTextBlock(TextBlockModel model) {
    if (!_documentLoaded ||
        _textPlacementEnabled ||
        _penEnabled ||
        _eraserEnabled ||
        !_elements.contains(model)) {
      return;
    }
    _startTextEditing(model);
    model.focusNode.requestFocus();
  }

  void _bringElementToFront(CanvasElementModel model) {
    if (!_documentLoaded || !_elements.contains(model)) return;
    _elements
      ..remove(model)
      ..add(model);
    _canvasController.bringToFront(model.data.id);
    _scheduleDocumentSave();
  }

  void _startTextEditing(TextBlockModel editing) {
    setState(() {
      _editingTextBlock = editing;
      _editingChromeModel = editing;
      for (final model in _elements.whereType<TextBlockModel>()) {
        model.editing = identical(model, editing);
      }
    });
  }

  void _clearTextEditing() {
    setState(() {
      _editingTextBlock = null;
      for (final model in _elements.whereType<TextBlockModel>()) {
        model.editing = false;
      }
    });
  }

  void _clearSelection() {
    _setSelection(const <Object>{});
  }

  void _setSelection(Set<Object> selection) {
    for (final model in _elements) {
      model.selected = selection.contains(model);
    }
  }

  Set<Object> _selectedModels() => {
    ..._elements.where((model) => model.selected),
  };

  GlobalKey _selectionKey(Object model) =>
      _selectionKeys.putIfAbsent(model, GlobalKey.new);

  void _moveSelectedChildren(CanvasElementModel dragged, Offset screenDelta) {
    if (!_documentLoaded ||
        _textPlacementEnabled ||
        _penEnabled ||
        _eraserEnabled ||
        _selectionModifierPressed.value ||
        screenDelta == Offset.zero) {
      return;
    }

    final selectedBeforeWidgetPointer = _selectionBeforeWidgetPointer;
    final draggedWasSelected = selectedBeforeWidgetPointer.contains(dragged);
    if (draggedWasSelected) _setSelection(selectedBeforeWidgetPointer);

    final draggedSelected =
        draggedWasSelected || (_elements.contains(dragged) && dragged.selected);

    if (!draggedSelected) _clearSelection();

    final gridDelta = screenDelta / _canvasController.scale;
    final affected = _elements
        .where(
          (model) =>
              identical(model, dragged) || draggedSelected && model.selected,
        )
        .toList();

    if (affected.isEmpty) return;
    _canvasController.moveChildrenBy(
      affected.map((model) => model.data.id),
      gridDelta,
    );
    for (final model in affected) {
      model.moveBy(gridDelta);
    }
  }

  void _resizeTextBlock(
    TextBlockModel model,
    Size renderedSize,
    Offset screenDelta,
  ) {
    if (!_documentLoaded ||
        _textPlacementEnabled ||
        _penEnabled ||
        _eraserEnabled) {
      return;
    }
    if (!_elements.contains(model)) return;
    final delta = screenDelta / _canvasController.scale;
    final angle = -model.data.rotation;
    final cosine = math.cos(angle);
    final sine = math.sin(angle);
    model.resize(
      renderedSize,
      Offset(
        delta.dx * cosine - delta.dy * sine,
        delta.dx * sine + delta.dy * cosine,
      ),
    );
  }

  void _rotateTextBlock(TextBlockModel model, double angle) {
    if (!_documentLoaded ||
        _textPlacementEnabled ||
        _penEnabled ||
        _eraserEnabled) {
      return;
    }
    if (!_elements.contains(model)) return;
    model.rotate(angle);
  }

  Offset _textBlockCenter(TextBlockModel model) {
    final renderObject = _selectionKey(
      model,
    ).currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return Offset.zero;
    return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
  }

  void _addTextBlock(Offset position) {
    if (!_documentLoaded) return;
    final node = TextElementData(
      id: const Uuid().v4(),
      position: position,
      width: textNodeDefaultWidth,
      height: null,
      markdown: '',
      style: const TextNodeStyle(
        fontFamily: 'Source Serif 4',
        fontSize: textNodeDefaultFontSize,
        color: '#201C1A',
      ),
    );
    final model = TextBlockModel(node);

    _mountElement(model, requestFocus: true);
    _startTextEditing(model);
    _scheduleDocumentSave();
  }

  CanvasElementModel _createElementModel(CanvasElementData data) {
    return switch (data) {
      final TextElementData data => TextBlockModel(data),
      final CodeElementData data => CodeBlockModel(data),
      final PenElementData data => PenStrokeModel(data),
      final ArrowElementData data => ArrowModel(data),
    };
  }

  void _mountElement(
    CanvasElementModel model, {
    bool requestFocus = false,
  }) {
    _elements.add(model);
    model.addListener(_scheduleDocumentSave);
    final child = switch (model) {
      final TextBlockModel text => _SelectionPointerRegion(
        key: _selectionKey(text),
        activeTool: _activeTool,
        modifierPressed: _selectionModifierPressed,
        rotationModel: text,
        onPointerDown: (event) => _handleTextBlockPointerDown(text, event),
        child: TextBlock(
          model: text,
          attachmentStore: _attachmentStore,
          onEdit: () => _editTextBlock(text),
          onMove: (delta) => _moveSelectedChildren(text, delta),
          onResize: (size, delta) => _resizeTextBlock(text, size, delta),
        ),
      ),
      final CodeBlockModel code => _SelectionPointerRegion(
        key: _selectionKey(code),
        activeTool: _activeTool,
        modifierPressed: _selectionModifierPressed,
        onPointerDown: (event) => _handleCodeBlockPointerDown(code, event),
        child: CodeBlock(
          model: code,
          onMove: (delta) => _moveSelectedChildren(code, delta),
        ),
      ),
      final PenStrokeModel pen => PenStroke(
        key: _selectionKey(pen),
        model: pen,
        onPointerDown: (event) => _handleStrokePointerDown(pen, event),
        onMove: (delta) => _moveSelectedChildren(pen, delta),
      ),
      final ArrowModel arrow => _SelectionPointerRegion(
        key: _selectionKey(arrow),
        activeTool: _activeTool,
        modifierPressed: _selectionModifierPressed,
        onPointerDown: (event) => _handleArrowPointerDown(arrow, event),
        child: Arrow(model: arrow),
      ),
      _ => throw StateError('Unknown canvas element model'),
    };
    final canvasChild = model is PenStrokeModel
        ? ListenableBuilder(
            listenable: _activeTool,
            builder: (context, child) => AbsorbPointer(
              absorbing: _activeTool.value != _CanvasTool.select,
              child: child,
            ),
            child: child,
          )
        : child;
    _canvasController.addChild(
      model.canvasPosition,
      canvasChild,
      id: model.data.id,
      childSize: model.canvasSize,
    );
    if (requestFocus) {
      final text = model as TextBlockModel;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => text.focusNode.requestFocus(),
      );
    }
  }

  void _handleCanvasPointerExit(PointerExitEvent event) {
    _canvasPointerPosition = null;
    if (_penEnabled) _penTool.onPointerExit(event);
  }

  void _handleCanvasPointerHover(PointerHoverEvent event) {
    _canvasPointerPosition = event.localPosition;
    if (_penEnabled && !_spaceHeld) _penTool.onPointerHover(event);
  }

  void _addCodeBlock() {
    if (!_documentLoaded) return;
    _prepareInteractiveBlock();
    final size = _fittedBlockSize(const Size(600, 400), codeBlockMinimumSize);
    var position = _viewportCenter() - Offset(size.width / 2, size.height / 2);
    final placementOffset = const Offset(24, 24) / _canvasController.scale;
    while (_elements.whereType<CodeBlockModel>().any(
      (block) => block.data.position == position,
    )) {
      position += placementOffset;
    }
    final model = CodeBlockModel(
      CodeElementData(
        id: const Uuid().v4(),
        position: position,
        size: size,
        language: CodeLanguage.dart,
        source: '',
      ),
    );
    _mountElement(model);
    _scheduleDocumentSave();
  }

  Size _fittedBlockSize(Size preferred, Size minimum) {
    final scale = _canvasController.scale;
    final viewport = _canvasController.canvasSize;
    return Size(
      math.max(
        minimum.width,
        math.min(preferred.width, (viewport.width - 32) / scale),
      ),
      math.max(
        minimum.height,
        math.min(preferred.height, (viewport.height - 32) / scale),
      ),
    );
  }

  void _prepareInteractiveBlock() {
    _clearTextEditing();
    setState(() {
      _activeTool.value = _CanvasTool.select;
      _eraserPointer = null;
      _spaceHeld = false;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _addStroke(Sketch sketch) {
    if (!_documentLoaded) return;
    final stroke = positionSketch(
      sketch,
      canvasOffset: _canvasController.offset,
      canvasScale: _canvasController.scale,
    );
    final model = PenStrokeModel(
      PenElementData(
        id: const Uuid().v4(),
        position: stroke.position,
        size: stroke.size,
        hitSlop: stroke.hitSlop,
        sketch: stroke.sketch,
      ),
    );
    _mountElement(model);
    _scheduleDocumentSave();
  }

  void _addArrow(ArrowModel model) {
    if (!_documentLoaded) return;
    _mountElement(model);
    _scheduleDocumentSave();
  }

  void _handleArrowPointerDown(
    ArrowModel model,
    PointerDownEvent event,
  ) {
    if (event.buttons != kPrimaryButton ||
        !_documentLoaded ||
        _textPlacementEnabled ||
        _penEnabled ||
        _eraserEnabled ||
        _arrowEnabled ||
        !_elements.contains(model)) {
      return;
    }
    _interactiveCanvasPointerIds.add(event.pointer);
    if (_selectionModifierPressed.value) {
      model.selected = !model.selected;
      return;
    }
    _bringElementToFront(model);
    _clearTextEditing();
    _dragArrowPointer = event.pointer;
    _dragArrow = model;
  }

  void _finishArrowDrag({bool select = false}) {
    if (select) _dragArrow?.selected = true;
    _dragArrowPointer = null;
    _dragArrow = null;
  }

  void _handleStrokePointerDown(
    PenStrokeModel model,
    PointerDownEvent event,
  ) {
    if (event.buttons != kPrimaryButton ||
        !_documentLoaded ||
        _textPlacementEnabled ||
        _penEnabled ||
        _eraserEnabled ||
        !_elements.contains(model)) {
      return;
    }
    _interactiveCanvasPointerIds.add(event.pointer);
    if (_selectionModifierPressed.value) {
      model.selected = !model.selected;
      return;
    }
    _bringElementToFront(model);
  }

  void _selectAll() {
    if (!_documentLoaded) return;
    for (final model in _elements) {
      model.selected = true;
    }
  }

  void _deleteSelected() {
    _removeElements(_elements.where((model) => model.selected));
  }

  bool get _editingElement {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null ||
        _elements.whereType<TextBlockModel>().any(
          (model) => model.focusNode.hasFocus,
        ) ||
        _elements.whereType<CodeBlockModel>().any(
          (model) => model.focusNode.hasFocus,
        );
  }

  List<CanvasElementModel> get _selectedInStackingOrder =>
      _elements.where((model) => model.selected).toList();

  void _handleWebCopy(ClipboardWriteEvent event) =>
      unawaited(_copySelection(event));

  void _handleWebCut(ClipboardWriteEvent event) =>
      unawaited(_copySelection(event, cut: true));

  void _handleWebPaste(ClipboardReadEvent event) {
    if (!_documentLoaded || _editingElement) return;
    unawaited(_pasteSelection(event.getClipboardReader()));
  }

  Future<void> _copySelection(
    ClipboardWriter? writer, {
    bool cut = false,
  }) async {
    if (!_documentLoaded || _editingElement) return;
    final selected = _selectedInStackingOrder;
    if (selected.isEmpty) return;
    final payload = encodeCanvasClipboard(
      selected.map((model) => model.data.copy()),
    );
    try {
      final write = widget.writeClipboardText;
      if (write != null) {
        await write(payload);
      } else {
        final clipboard = writer ?? SystemClipboard.instance;
        if (clipboard == null) throw StateError('Clipboard unavailable');
        final item = DataWriterItem()..add(Formats.plainText(payload));
        await clipboard.write([item]);
      }
      if (!mounted) return;
      _lastPastedPayload = null;
      _pasteOffset = Offset.zero;
      _cutPayload = cut ? payload : null;
      _pointerReference = (payload, _canvasPointerPosition);
      if (cut) _removeElements(selected);
    } on Object {
      _showProjectSnackBar(
        cut
            ? 'Could not cut canvas elements'
            : 'Could not copy canvas elements',
      );
    }
  }

  Future<void> _pasteSelection(Future<ClipboardReader>? readerFuture) async {
    try {
      final read = widget.readClipboardText;
      final text = read != null
          ? await read()
          : await (await readerFuture!).readValue(Formats.plainText);
      if (text == null) return;
      final elements = decodeCanvasClipboard(text);
      if (elements == null) return;
      if (!mounted || !_documentLoaded) return;

      final pointer = _canvasPointerPosition;
      final placeAtPointer =
          pointer != null && (text, pointer) != _pointerReference;
      final pasted = [
        for (final element in elements)
          _createElementModel(element.copy(id: const Uuid().v4())),
      ];
      if (placeAtPointer) {
        final bounds = pasted
            .map((model) => model.canvasPosition & model.canvasSize)
            .reduce((bounds, next) => bounds.expandToInclude(next));
        _pasteOffset =
            _canvasController.offset +
            pointer / _canvasController.scale -
            bounds.center;
      } else if (_lastPastedPayload != text) {
        _pasteOffset = text == _cutPayload
            ? Offset.zero
            : const Offset(24, 24) / _canvasController.scale;
      } else {
        _pasteOffset += const Offset(24, 24) / _canvasController.scale;
      }
      _lastPastedPayload = text;
      _pointerReference = (text, pointer);
      for (final model in pasted) {
        model.moveBy(_pasteOffset);
        _mountElement(model);
      }
      _clearTextEditing();
      _setSelection(pasted.toSet());
      _scheduleDocumentSave();
    } on Object {
      _showProjectSnackBar('Could not paste canvas elements');
    }
  }

  void _eraseAt(Offset globalPosition) {
    final hits = <CanvasElementModel>[];
    for (final model in _elements) {
      final renderObject = _selectionKeys[model]?.currentContext
          ?.findRenderObject();
      if (renderObject is RenderBox &&
          renderObject.hitTest(
            BoxHitTestResult(),
            position: renderObject.globalToLocal(globalPosition),
          )) {
        hits.add(model);
      }
    }
    _removeElements(hits);
  }

  void _removeElements(Iterable<CanvasElementModel> models) {
    if (!_documentLoaded) return;
    final modelsToDispose = models.where(_elements.contains).toList();
    if (modelsToDispose.isEmpty) return;

    final removesEditingText = modelsToDispose.any(
      (model) =>
          model is TextBlockModel &&
          (identical(model, _editingTextBlock) ||
              identical(model, _editingChromeModel)),
    );
    if (removesEditingText) {
      _clearTextEditing();
      setState(() => _editingChromeModel = null);
    }
    for (final model in modelsToDispose) {
      if (model case final TextBlockModel text) text.focusNode.unfocus();
      if (model case final CodeBlockModel code) code.focusNode.unfocus();
      _canvasController.removeChild(model.data.id);
      _elements.remove(model);
      _selectionKeys.remove(model);
      _selectionBeforeDrag.remove(model);
      _selectionBeforeWidgetPointer.remove(model);
      model.removeListener(_scheduleDocumentSave);
    }
    if (_selectionBeforeWidgetPointer.isEmpty) _widgetPointer = null;
    if (modelsToDispose.contains(_dragArrow)) _finishArrowDrag();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final model in modelsToDispose) {
        model.dispose();
      }
    });
    _scheduleDocumentSave();
  }

  void _showSettingsDialog() {
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: BTheme.of(context).colors.scrim,
        builder: (_) => SettingsDialog(
          canvasBackgroundKind: _canvasBackgroundKind,
          onCanvasBackgroundChanged: _setCanvasBackground,
          onImportCanvas: _importProject,
          onExportCanvas: _exportProject,
        ),
      ),
    );
  }

  Future<void> _exportProject() async {
    if (_projectTransferActive || !_documentLoaded) return;
    _projectTransferActive = true;
    try {
      final snapshot = _currentDocument();
      final bytes = await encodeCanvasProject(snapshot, _attachmentStore);
      if (await _projectFiles.save(bytes)) {
        _showProjectSnackBar('Canvas exported');
      }
    } on Object {
      _showProjectSnackBar('Could not export canvas');
    } finally {
      _projectTransferActive = false;
    }
  }

  Future<bool> _importProject() async {
    if (_projectTransferActive || !_documentLoaded) return false;
    _projectTransferActive = true;
    try {
      final bytes = await _projectFiles.open();
      if (bytes == null) return false;
      final project = await decodeCanvasProject(bytes);

      _saveTimer?.cancel();
      _saveTimer = null;
      final dirtyFlush = _documentDirty
          ? _enqueueDocumentSave(throwOnFailure: true)
          : null;
      _documentLoaded = false;
      if (dirtyFlush != null) await dirtyFlush;

      final operation = _saveQueue.then((_) => _commitImportedProject(project));
      _saveQueue = operation.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {},
      );
      await operation;
      _showProjectSnackBar('Canvas imported');
      return true;
    } on Object {
      if (!_documentLoaded) {
        _documentLoaded = true;
        if (mounted) setState(() {});
      }
      _showProjectSnackBar('Could not import canvas');
      return false;
    } finally {
      _projectTransferActive = false;
    }
  }

  Future<void> _commitImportedProject(CanvasProject project) async {
    final currentDocument = _currentDocument();
    final currentPaths = canvasAttachmentPaths(currentDocument);
    final importedPaths = project.attachments.keys.toSet();
    final collisionPaths = currentPaths.intersection(importedPaths).toList()
      ..sort();
    final backups = <String, Uint8List>{};
    final attemptedPaths = <String>[];

    try {
      for (final path in collisionPaths) {
        final bytes = await _attachmentStore.readIfExists(path);
        if (bytes == null) {
          throw StateError('Missing current attachment: $path');
        }
        backups[path] = Uint8List.fromList(bytes);
      }

      try {
        final paths = project.attachments.keys.toList()..sort();
        for (final path in paths) {
          attemptedPaths.add(path);
          await _attachmentStore.write(path, project.attachments[path]!);
        }
        await _persistDocument(project.document);
      } on Object catch (error, stackTrace) {
        Object? rollbackError;
        StackTrace? rollbackStackTrace;
        for (final path in attemptedPaths) {
          final backup = backups[path];
          if (backup == null) continue;
          try {
            await _attachmentStore.write(path, Uint8List.fromList(backup));
          } on Object catch (error, stackTrace) {
            rollbackError ??= error;
            rollbackStackTrace ??= stackTrace;
          }
        }
        if (rollbackError != null) {
          debugPrint(
            'Canvas import rollback failed: $rollbackError\n'
            '$rollbackStackTrace',
          );
        }
        Error.throwWithStackTrace(error, stackTrace);
      }

      _replaceLiveModels(project.document);
    } on Object {
      _documentLoaded = true;
      if (mounted) setState(() {});
      rethrow;
    }
  }

  void _replaceLiveModels(CanvasDocument document) {
    final oldElements = List<CanvasElementModel>.of(_elements);
    _clearTextEditing();
    FocusManager.instance.primaryFocus?.unfocus();
    _arrowTool.cancel();
    _activeTool.value = _CanvasTool.select;
    _eraserPointer = null;
    _spaceHeld = false;
    _interactiveCanvasPointerIds.clear();
    _selectionBeforeWidgetPointer.clear();
    _selectionBeforeDrag.clear();
    _selectionKeys.clear();
    _widgetPointer = null;
    _dragSelectionPointer = null;
    _dragSelectionStart = null;
    _dragSelectionEnd = null;
    _dragArrowPointer = null;
    _dragArrow = null;
    _editingTextBlock = null;
    _editingChromeModel = null;

    for (final model in oldElements) {
      model.removeListener(_scheduleDocumentSave);
    }
    _elements.clear();
    _canvasController.clear();
    _canvasBackgroundKind = document.background;
    _canvasController.background = document.background.build(
      BTheme.of(context).colors,
    );
    for (final data in document.elements) {
      _mountElement(_createElementModel(data));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final model in oldElements) {
        model.dispose();
      }
    });
    _documentDirty = false;
    _documentLoaded = true;
    if (mounted) setState(() {});
  }

  void _showProjectSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setCanvasBackground(CanvasBackgroundKind kind) {
    if (!_documentLoaded || _canvasBackgroundKind == kind) return;
    _canvasBackgroundKind = kind;
    _canvasController.background = kind.build(BTheme.of(context).colors);
    _scheduleDocumentSave();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!_documentLoaded) return false;
    _selectionModifierPressed.value =
        Theme.of(context).platform == TargetPlatform.macOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;
    if (_editingElement) return false;
    if (event is KeyDownEvent &&
        _selectionModifierPressed.value &&
        _clipboardEvents == null) {
      if (event.logicalKey == LogicalKeyboardKey.keyC ||
          event.logicalKey == LogicalKeyboardKey.keyX) {
        if (_selectedInStackingOrder.isEmpty) return false;
        unawaited(
          _copySelection(
            null,
            cut: event.logicalKey == LogicalKeyboardKey.keyX,
          ),
        );
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        final read = widget.readClipboardText;
        final clipboard = SystemClipboard.instance;
        if (read == null && clipboard == null) {
          _showProjectSnackBar('Could not paste canvas elements');
          return true;
        }
        unawaited(_pasteSelection(read != null ? null : clipboard!.read()));
        return true;
      }
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyA &&
        _selectionModifierPressed.value) {
      _selectAll();
      return true;
    }
    final deletionKey =
        event.logicalKey == LogicalKeyboardKey.delete ||
        (Theme.of(context).platform == TargetPlatform.macOS &&
            event.logicalKey == LogicalKeyboardKey.backspace);
    if ((event is KeyDownEvent || event is KeyRepeatEvent) && deletionKey) {
      _deleteSelected();
      return true;
    }
    if ((!_penEnabled && !_eraserEnabled) ||
        event.logicalKey != LogicalKeyboardKey.space) {
      return false;
    }
    final held = event is! KeyUpEvent;
    if (_spaceHeld != held) setState(() => _spaceHeld = held);
    return true;
  }

  Future<void> _restoreDocument() async {
    try {
      final document = await _documentStore.load();
      if (!mounted) return;
      if (document != null) {
        _canvasBackgroundKind = document.background;
        _canvasController.background = document.background.build(
          BTheme.of(context).colors,
        );
        for (final data in document.elements) {
          _mountElement(_createElementModel(data));
        }
      }
      _documentLoaded = true;
      if (mounted) setState(() {});
    } on Object {
      _documentLoaded = true;
      if (!mounted) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load saved canvas')),
        );
      });
    }
  }

  CanvasDocument _currentDocument() {
    return CanvasDocument(
      background: _canvasBackgroundKind,
      elements: _elements.map((model) => model.data.copy()).toList(),
    );
  }

  void _scheduleDocumentSave() {
    if (!_documentLoaded) return;
    _documentDirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 300),
      _enqueueDocumentSave,
    );
  }

  Future<void>? _enqueueDocumentSave({bool throwOnFailure = false}) {
    _saveTimer = null;
    if (!_documentLoaded || !_documentDirty) return null;
    _documentDirty = false;
    final snapshot = _currentDocument();
    final operation = _saveQueue.then(
      (_) =>
          throwOnFailure ? _persistDocument(snapshot) : _saveDocument(snapshot),
    );
    _saveQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    if (!throwOnFailure) return null;
    return _saveAndRestoreDirty(operation);
  }

  Future<void> _saveAndRestoreDirty(Future<void> operation) async {
    try {
      await operation;
    } on Object {
      _documentDirty = true;
      rethrow;
    }
  }

  Future<void> _persistDocument(CanvasDocument document) {
    return _documentStore.save(document);
  }

  Future<void> _saveDocument(CanvasDocument document) async {
    try {
      await _persistDocument(document);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save canvas')),
      );
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_documentLoaded && _documentDirty) {
      unawaited(_enqueueDocumentSave() ?? Future<void>.value());
    }
    unawaited(_saveQueue);
    for (final model in _elements) {
      model
        ..removeListener(_scheduleDocumentSave)
        ..dispose();
    }
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _clipboardEvents
      ?..unregisterCopyEventListener(_handleWebCopy)
      ..unregisterCutEventListener(_handleWebCut)
      ..unregisterPasteEventListener(_handleWebPaste);
    _activeTool.dispose();
    _selectionModifierPressed.dispose();
    _penTool.dispose();
    _arrowTool
      ..removeListener(_handleArrowToolChanged)
      ..dispose();
    _canvasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final geo = theme.geo;
    final editingChromeModel = _editingChromeModel;
    return Scaffold(
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: !_documentLoaded,
            child: MouseRegion(
              cursor: !_spaceHeld && _penEnabled
                  ? SystemMouseCursors.none
                  : !_spaceHeld && _eraserEnabled
                  ? SystemMouseCursors.precise
                  : MouseCursor.defer,
              onExit: _handleCanvasPointerExit,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _handleCanvasPointerDown,
                onPointerMove: _handleCanvasPointerMove,
                onPointerUp: _handleCanvasPointerUp,
                onPointerCancel: _handleCanvasPointerCancel,
                onPointerHover: _handleCanvasPointerHover,
                child: LazyCanvas(
                  controller: _canvasController,
                  mousePanButtons:
                      kSecondaryMouseButton |
                      kMiddleMouseButton |
                      (_spaceHeld ? kPrimaryMouseButton : 0),
                ),
              ),
            ),
          ),
          if (_arrowTool.preview case final preview?)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('arrow-preview'),
                  painter: ArrowPreviewPainter(
                    geometry: preview.geometry,
                    canvasOffset: _canvasController.offset,
                    canvasScale: _canvasController.scale,
                    color: colors.accent,
                  ),
                ),
              ),
            ),
          if (_penEnabled)
            Positioned.fill(
              child: IgnorePointer(
                child: Scribble(notifier: _penTool),
              ),
            ),
          if ((_dragSelectionStart, _dragSelectionEnd) case (
            final start?,
            final end?,
          ))
            Positioned.fromRect(
              key: const ValueKey('drag-selection-marquee'),
              rect: Rect.fromPoints(start, end),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.accentSubtle.withValues(alpha: 0.45),
                    border: Border.all(color: colors.accent),
                  ),
                ),
              ),
            ),
          if (editingChromeModel case final anchor?)
            ListenableBuilder(
              listenable: anchor,
              builder: (context, _) => CompositedTransformFollower(
                link: anchor.layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.center,
                followerAnchor: Alignment.center,
                offset:
                    TextBlockControls.followerOffset +
                    Offset(
                      TextBlockControls.size.width / 2 - anchor.node.width / 2,
                      0,
                    ),
                child: SizedBox.fromSize(
                  size: TextBlockControls.size,
                  child: Overlay.wrap(
                    clipBehavior: Clip.none,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      reverseDuration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: _textEditingChromeTransition,
                      child: switch (_editingTextBlock) {
                        final editing? => ListenableBuilder(
                          key: ValueKey(editing.node.id),
                          listenable: editing,
                          builder: (context, child) => IgnorePointer(
                            ignoring: !editing.editing,
                            child: child,
                          ),
                          child: TextBlockControls(
                            key: ValueKey(editing.node.id),
                            model: editing,
                            onMove: (delta) =>
                                _moveSelectedChildren(editing, delta),
                            onRotate: (angle) =>
                                _rotateTextBlock(editing, angle),
                            rotationCenter: () => _textBlockCenter(editing),
                          ),
                        ),
                        null => const SizedBox(
                          key: ValueKey('text-editing-chrome-hidden'),
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ControlSurface(
                  key: const ValueKey('toolbar-surface'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Place text',
                        child: Button(
                          variant: ButtonVariant.toolbar,
                          size: ButtonSize.toolbar,
                          selected: _textPlacementEnabled,
                          onPressed: () => _toggleTool(_CanvasTool.text),
                          child: const Text('Text'),
                        ),
                      ),
                      Tooltip(
                        message: 'Add code block',
                        child: Button(
                          variant: ButtonVariant.toolbar,
                          size: ButtonSize.toolbar,
                          onPressed: _addCodeBlock,
                          child: const Text('Code'),
                        ),
                      ),
                      Tooltip(
                        message: 'Draw with pen',
                        child: Button(
                          variant: ButtonVariant.toolbar,
                          size: ButtonSize.toolbar,
                          selected: _penEnabled,
                          onPressed: () => _toggleTool(_CanvasTool.pen),
                          child: const Text('Draw'),
                        ),
                      ),
                      Tooltip(
                        message: 'Erase elements',
                        child: Button(
                          variant: ButtonVariant.toolbar,
                          size: ButtonSize.toolbar,
                          selected: _eraserEnabled,
                          onPressed: () => _toggleTool(_CanvasTool.eraser),
                          child: const Text('Erase'),
                        ),
                      ),
                      Tooltip(
                        message: 'Draw an arrow',
                        child: Button(
                          variant: ButtonVariant.toolbar,
                          size: ButtonSize.toolbar,
                          selected: _arrowEnabled,
                          onPressed: () => _toggleTool(_CanvasTool.arrow),
                          child: const Text('Arrow'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  MediaQuery.sizeOf(context).width < 600 ? 72 : 12,
                  12,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ControlSurface(
                      key: const ValueKey('settings-button-surface'),
                      child: IconButton(
                        key: const ValueKey('settings-button'),
                        tooltip: 'Settings',
                        onPressed: _showSettingsDialog,
                        style: _toolbarIconButtonStyle(colors, geo),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ),
                    if (_penEnabled) ...[
                      const SizedBox(height: 8),
                      _DrawSettings(
                        color: _penColor,
                        width: _penWidth,
                        onColorChanged: _setPenColor,
                        onWidthChanged: _setPenWidth,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawSettings extends StatelessWidget {
  const _DrawSettings({
    required this.color,
    required this.width,
    required this.onColorChanged,
    required this.onWidthChanged,
  });

  final Color color;
  final double width;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final swatches = presetColors.where(
      (swatch) => const {
        'Black',
        'Gray',
        'Red',
        'Orange',
        'Green',
        'Blue',
      }.contains(swatch.label),
    );
    return ControlSurface(
      key: const ValueKey('draw-settings-panel'),
      child: SizedBox(
        width: 248,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Color', style: theme.typo.label),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final swatch in swatches)
                    Tooltip(
                      message: swatch.label,
                      child: Semantics(
                        button: true,
                        selected: color == swatch.color,
                        label: swatch.label,
                        child: InkWell(
                          key: ValueKey(
                            'draw-color-${swatch.label.toLowerCase()}',
                          ),
                          customBorder: const CircleBorder(),
                          onTap: () => onColorChanged(swatch.color),
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: swatch.color,
                                border: Border.all(
                                  color: color == swatch.color
                                      ? colors.focusRing
                                      : colors.borderSubtle,
                                  width: color == swatch.color ? 2 : 1,
                                ),
                              ),
                              child: const SizedBox.square(dimension: 22),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Width', style: theme.typo.label),
              DiscreteSlider(
                value: width,
                onChanged: onWidthChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionPointerRegion extends StatelessWidget {
  const _SelectionPointerRegion({
    required this.activeTool,
    required this.modifierPressed,
    required this.onPointerDown,
    required this.child,
    this.rotationModel,
    super.key,
  });

  final ValueListenable<_CanvasTool> activeTool;
  final ValueListenable<bool> modifierPressed;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final Widget child;
  final TextBlockModel? rotationModel;

  @override
  Widget build(BuildContext context) {
    final listener = Listener(
      onPointerDown: onPointerDown,
      child: ListenableBuilder(
        listenable: Listenable.merge([activeTool, modifierPressed]),
        builder: (context, child) => AbsorbPointer(
          absorbing:
              activeTool.value != _CanvasTool.select || modifierPressed.value,
          child: child,
        ),
        child: child,
      ),
    );
    return rotationModel == null
        ? listener
        : ListenableBuilder(
            listenable: rotationModel!,
            builder: (context, child) => Transform.rotate(
              angle: rotationModel!.node.rotation,
              child: child,
            ),
            child: listener,
          );
  }
}

Widget _textEditingChromeTransition(
  Widget child,
  Animation<double> animation,
) {
  return FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
      alignment: Alignment.centerLeft,
      child: child,
    ),
  );
}

ButtonStyle _toolbarButtonStyle(BColors colors, BGeo geo) {
  return ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(colors.textSecondary),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return colors.surfacePressed;
      }
      if (states.contains(WidgetState.hovered)) return colors.surfaceHover;
      return Colors.transparent;
    }),
    side: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: colors.focusRing)
          : BorderSide.none,
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: geo.radiusSmall),
    ),
  );
}

ButtonStyle _toolbarIconButtonStyle(BColors colors, BGeo geo) {
  return _toolbarButtonStyle(
    colors,
    geo,
  ).copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.all(8)));
}
