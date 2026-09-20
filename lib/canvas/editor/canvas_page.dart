// Provides the infinite canvas editor and coordinates tools and persistence.
// Used as the application's primary workspace screen.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_background.dart';
import 'package:beyond/canvas/editor/canvas_clipboard.dart';
import 'package:beyond/canvas/editor/canvas_element_model.dart';
import 'package:beyond/canvas/editor/widgets/arrow_stroke_style_icon.dart';
import 'package:beyond/canvas/editor/widgets/element_transform_controls.dart';
import 'package:beyond/canvas/editor/widgets/tool_options.dart';
import 'package:beyond/canvas/editor/widgets/toolbar_button.dart';
import 'package:beyond/canvas/editor/widgets/zoom_control.dart';
import 'package:beyond/canvas/persistence/attachments/store.dart';
import 'package:beyond/canvas/persistence/canvas_document_store.dart';
import 'package:beyond/canvas/persistence/canvas_project.dart';
import 'package:beyond/canvas/persistence/canvas_project_files.dart';
import 'package:beyond/canvas/tools/arrow/arrow_tool.dart';
import 'package:beyond/canvas/tools/code/code_tool.dart';
import 'package:beyond/canvas/tools/media/media_tool.dart';
import 'package:beyond/canvas/tools/pen/pen_tool.dart';
import 'package:beyond/canvas/tools/shape/shape_tool.dart';
import 'package:beyond/canvas/tools/text/text_tool.dart';
import 'package:beyond/settings/settings_dialog.dart';
import 'package:beyond/theme/preset_colors.dart';
import 'package:beyond/theme/theme.dart';
import 'package:beyond/ui/common/b_container.dart';
import 'package:beyond/ui/common/color_picker.dart';
import 'package:beyond/ui/common/discrete_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:uuid/uuid.dart';

// ---------- Tools and presets ----------

enum _CanvasTool { select, text, code, media, shape, pen, arrow, eraser }

final List<({String label, Color color})> _toolColorSwatches = presetColors
    .where(
      (swatch) => switch (swatch.label) {
        'Black' || 'Gray' || 'Red' => true,
        _ => false,
      },
    )
    .toList(growable: false);

// ---------- Canvas workspace ----------

/// Coordinates the infinite canvas, element tools, persistence, and transfer.
/// Used as the application's primary interactive workspace.
class CanvasPage extends StatefulWidget {
  // ---------- Construction ----------

  const CanvasPage({
    this.attachmentStore,
    this.documentStore,
    this.projectFiles,
    this.readClipboard,
    this.writeClipboardText,
    super.key,
  });

  final AttachmentStore? attachmentStore;
  final CanvasDocumentStore? documentStore;
  final CanvasProjectFiles? projectFiles;
  final Future<CanvasClipboardSnapshot> Function()? readClipboard;
  final Future<void> Function(String text)? writeClipboardText;

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  // ---------- Constants ----------

  static const _historyLimit = 50;
  static const _noIconsPreferenceKey = 'interface.no_icons';

  // ---------- State ----------

  final _canvasController = LazyCanvasController(
    buildExtentMultiplier: 3.4,
    useIdsFromArgs: true,
  );
  CanvasBackgroundKind _canvasBackgroundKind = CanvasBackgroundKind.dotGrid;
  late final CanvasDocumentStore _documentStore = widget.documentStore ?? CanvasDocumentStore();
  late final AttachmentStore _attachmentStore = widget.attachmentStore ?? createAttachmentStore();
  late final CanvasProjectFiles _projectFiles = widget.projectFiles ?? createCanvasProjectFiles();
  final _elements = <CanvasElementModel>[];
  CanvasElementModel? _activeElement;
  TextBlockModel? _editingTextBlock;
  CanvasElementModel? _editingChromeModel;
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
  late final ShapeTool _shapeTool;
  Color? _customPenColor;
  Color? _customShapeStrokeColor;
  Color? _customArrowColor;
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
  final ValueNotifier<Offset?> _canvasPointerPosition = ValueNotifier(null);
  (String, Offset?)? _pointerReference;
  final _undoHistory = <String>[];
  final _redoHistory = <String>[];
  final _preferences = SharedPreferencesAsync();
  String? _historyCurrent;
  var _historyOperationActive = false;
  var _noIcons = false;
  var _noIconsChanged = false;
  var _penColorPickerExpanded = false;
  var _shapeOutlineColorPickerExpanded = false;
  var _arrowColorPickerExpanded = false;
  var _textColorPickerExpanded = false;

  Color get _penColor => _customPenColor ?? BTheme.of(context).colors.textPrimary;

  bool get _penEnabled => _activeTool.value == _CanvasTool.pen;

  bool get _arrowEnabled => _activeTool.value == _CanvasTool.arrow;

  bool get _shapeEnabled => _activeTool.value == _CanvasTool.shape;

  ValueChanged<Offset>? get _placementAction => switch (_activeTool.value) {
    _CanvasTool.text => _addTextBlock,
    _CanvasTool.code => _addCodeBlock,
    _CanvasTool.media => _addMedia,
    _ => null,
  };

  bool get _placementEnabled => _placementAction != null;

  bool get _eraserEnabled => _activeTool.value == _CanvasTool.eraser;

  TextBlockModel? get _activeTextBlock => switch (_activeElement) {
    final TextBlockModel model => model,
    _ => null,
  };

  CodeBlockModel? get _activeCodeBlock => switch (_activeElement) {
    final CodeBlockModel model => model,
    _ => null,
  };

  ShapeModel? get _activeShape => switch (_activeElement) {
    final ShapeModel model => model,
    _ => null,
  };

  ArrowModel? get _activeArrow => switch (_activeElement) {
    final ArrowModel model => model,
    _ => null,
  };

  // ---------- Lifecycle ----------

  @override
  void initState() {
    super.initState();
    _penTool = PenTool(onStroke: _addStroke)..setStrokeWidth(_penWidth);
    _arrowTool = ArrowTool(onArrow: _addArrow)..addListener(_handleDrawingToolChanged);
    _shapeTool = ShapeTool(onShape: _addShape)..addListener(_handleDrawingToolChanged);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _clipboardEvents = widget.readClipboard == null && widget.writeClipboardText == null
        ? ClipboardEvents.instance
        : null;
    _clipboardEvents
      ?..registerCopyEventListener(_handleWebCopy)
      ..registerCutEventListener(_handleWebCut)
      ..registerPasteEventListener(_handleWebPaste);
    unawaited(_restoreNoIcons());
    unawaited(_restoreDocument());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colors = BTheme.of(context).colors;
    _canvasController.background = _canvasBackgroundKind.build(colors);
    if (_customPenColor == null) _penTool.setColor(colors.textPrimary);
    if (_customShapeStrokeColor == null) {
      _shapeTool.setStrokeColor(colors.textSecondary);
    }
    if (_customArrowColor == null) {
      _arrowTool.setColor(colors.textSecondary);
    }
  }

  FocusNode? _editorFocusNode(CanvasElementModel model) => switch (model) {
    final TextBlockModel text => text.focusNode,
    final CodeBlockModel code => code.focusNode,
    final MediaModel media => media.focusNode,
    _ => null,
  };

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_documentLoaded && _documentDirty) {
      unawaited(_enqueueDocumentSave() ?? Future<void>.value());
    }
    unawaited(_saveQueue);
    for (final model in _elements) {
      _editorFocusNode(model)?.removeListener(_finishHistoryOperation);
      model.documentChanges.removeListener(_scheduleDocumentSave);
      model.dispose();
    }
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _clipboardEvents
      ?..unregisterCopyEventListener(_handleWebCopy)
      ..unregisterCutEventListener(_handleWebCut)
      ..unregisterPasteEventListener(_handleWebPaste);
    _activeTool.dispose();
    _selectionModifierPressed.dispose();
    _canvasPointerPosition.dispose();
    _penTool.dispose();
    _arrowTool
      ..removeListener(_handleDrawingToolChanged)
      ..dispose();
    _shapeTool
      ..removeListener(_handleDrawingToolChanged)
      ..dispose();
    _canvasController.dispose();
    super.dispose();
  }

  // ---------- Preferences ----------

  Future<void> _restoreNoIcons() async {
    try {
      final noIcons = await _preferences.getBool(_noIconsPreferenceKey) ?? false;
      if (mounted && !_noIconsChanged && noIcons != _noIcons) {
        setState(() => _noIcons = noIcons);
      }
    } on Object {
      // Keep the icon default when preferences are unavailable.
    }
  }

  void _setNoIcons(bool noIcons) {
    if (noIcons == _noIcons) return;
    _noIconsChanged = true;
    setState(() => _noIcons = noIcons);
    unawaited(_persistNoIcons(noIcons));
  }

  Future<void> _persistNoIcons(bool noIcons) async {
    try {
      await _preferences.setBool(_noIconsPreferenceKey, noIcons);
    } on Object {
      // The live setting still works when persistence is unavailable.
    }
  }

  // ---------- Tool selection ----------

  void _handleDrawingToolChanged() {
    if (mounted) setState(() {});
  }

  void _toggleTool(_CanvasTool tool) {
    if (!_documentLoaded) return;
    final enabling = _activeTool.value != tool;
    _clearElementEditing();
    setState(() {
      _activeTool.value = enabling ? tool : _CanvasTool.select;
      _eraserPointer = null;
      _spaceHeld = false;
    });
  }

  void _setPenColor(Color color) {
    setState(() => _customPenColor = color);
    _penTool.setColor(color);
  }

  void _setPenWidth(double width) {
    setState(() => _penWidth = width);
    _penTool.setStrokeWidth(width);
  }

  void _setShapeStrokeColor(Color color) {
    _customShapeStrokeColor = color;
    _shapeTool.setStrokeColor(color);
  }

  void _setArrowColor(Color color) {
    _customArrowColor = color;
    _arrowTool.setColor(color);
  }

  void _editElement(CanvasElementModel model, VoidCallback edit) {
    if (!_elements.contains(model)) return;
    _finishHistoryOperation();
    edit();
    _finishHistoryOperation();
  }

  // ---------- Canvas pointer events ----------

  bool _tryPlaceActiveTool(Offset position) {
    final place = _placementAction;
    if (place == null) return false;
    setState(() => _activeTool.value = _CanvasTool.select);
    place(position);
    return true;
  }

  Offset _screenToCanvas(Offset screenPosition) => _canvasController.offset + screenPosition / _canvasController.scale;

  void _handleCanvasPointerDown(PointerDownEvent event) {
    if (!_documentLoaded) return;
    _canvasPointerPosition.value = event.localPosition;
    if (_eraserEnabled && !_spaceHeld) {
      if (_eraserPointer == null && (event.kind != PointerDeviceKind.mouse || event.buttons == kPrimaryButton)) {
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
    final position = _screenToCanvas(event.localPosition);
    if (_tryPlaceActiveTool(position)) return;
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
      _arrowTool.onPointerDown(event, position);
      return;
    }
    if (_shapeEnabled) {
      _shapeTool.onPointerDown(event, position);
      return;
    }
    _clearElementEditing();
    _selectionBeforeDrag
      ..clear()
      ..addAll(_selectedModels());
    _toggleDragSelection = _selectionModifierPressed.value;
    if (!_toggleDragSelection) _clearSelection();
    if (event.kind != PointerDeviceKind.mouse || _penEnabled || _eraserEnabled) {
      return;
    }
    setState(() {
      _dragSelectionPointer = event.pointer;
      _dragSelectionStart = event.localPosition;
      _dragSelectionEnd = null;
    });
  }

  void _handleCanvasPointerMove(PointerMoveEvent event) {
    _canvasPointerPosition.value = event.localPosition;
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
        _screenToCanvas(event.localPosition),
      );
      return;
    }
    if (_shapeTool.ownsPointer(event.pointer)) {
      _shapeTool.onPointerMove(
        event,
        _screenToCanvas(event.localPosition),
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
      _finishHistoryOperation();
      return;
    }
    _finishWidgetPointer(event.pointer);
    if (_arrowTool.ownsPointer(event.pointer)) {
      _arrowTool.onPointerUp(
        event,
        _screenToCanvas(event.localPosition),
      );
      return;
    }
    if (_shapeTool.ownsPointer(event.pointer)) {
      _shapeTool.onPointerUp(
        event,
        _screenToCanvas(event.localPosition),
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
      _finishHistoryOperation();
      return;
    }
    _finishWidgetPointer(event.pointer);
    if (_arrowTool.ownsPointer(event.pointer)) {
      _arrowTool.onPointerCancel(event);
      return;
    }
    if (_shapeTool.ownsPointer(event.pointer)) {
      _shapeTool.onPointerCancel(event);
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

  // ---------- Selection ----------

  void _updateDragSelection(Offset end) {
    final start = _dragSelectionStart;
    if (start == null) return;
    if (_dragSelectionEnd == null && (end - start).distance <= kPrecisePointerPanSlop) {
      return;
    }
    setState(() => _dragSelectionEnd = end);
    final rect = Rect.fromPoints(start, end);
    final positions = {
      for (final child in _canvasController.widgetsWithScreenPositions()) child.id: child.ssPosition,
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
          _selectionRectOverlaps(
            rect,
            position & (renderObject.size * _canvasController.scale),
            model is RotatableCanvasElementModel ? model.rotation : 0,
          );
      return _toggleDragSelection ? _selectionBeforeDrag.contains(model) != overlaps : overlaps;
    }

    for (final model in _elements) {
      model.selected = selected(model);
    }
  }

  bool _selectionRectOverlaps(Rect selection, Rect element, double rotation) {
    if (rotation == 0) return selection.overlaps(element);
    final center = element.center;
    final transform = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..rotateZ(rotation)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    final elementPath = (Path()..addRect(element)).transform(
      transform.storage,
    );
    final overlap = Path.combine(
      PathOperation.intersect,
      Path()..addRect(selection),
      elementPath,
    ).getBounds();
    return !overlap.isEmpty;
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
    _finishHistoryOperation();
  }

  bool _toggleSelectionIfModifierPressed(CanvasElementModel model) {
    if (!_selectionModifierPressed.value) return false;
    model.selected = !model.selected;
    return true;
  }

  void _handleCodeBlockPointerDown(
    CodeBlockModel model,
    PointerDownEvent event,
  ) {
    if (event.buttons != kPrimaryButton || !_documentLoaded || _placementEnabled || _penEnabled || _eraserEnabled) {
      return;
    }
    _interactiveCanvasPointerIds.add(event.pointer);
    if (!_elements.contains(model)) return;
    if (_toggleSelectionIfModifierPressed(model)) return;
    if (!model.active) _setActiveElement(null);
    if (model.focusNode.hasFocus) _finishHistoryOperation();
    _clearTextEditing();
    _bringElementToFront(model);
  }

  void _editCodeBlock(CodeBlockModel model) {
    if (!_documentLoaded || _placementEnabled || _penEnabled || _eraserEnabled || !_elements.contains(model)) {
      return;
    }
    _clearTextEditing();
    _setActiveElement(model);
    // re_editor does not restart cursor/input state when readOnly changes while focused.
    // Refocus after the editable frame so the first click shows a working caret.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && model.active && _elements.contains(model)) {
        model.focusNode.unfocus();
        FocusManager.instance.applyFocusChangesIfNeeded();
        model.focusNode.requestFocus();
      }
    });
  }

  void _handleTextBlockPointerDown(
    TextBlockModel model,
    PointerDownEvent event,
  ) {
    if (event.buttons != kPrimaryButton || _placementEnabled || _penEnabled || _eraserEnabled) {
      return;
    }
    _interactiveCanvasPointerIds.add(event.pointer);
    if (!_elements.contains(model)) return;
    if (_toggleSelectionIfModifierPressed(model)) return;
    if (!model.active) _setActiveElement(null);
    if (model.focusNode.hasFocus) _finishHistoryOperation();
    if (!model.editing) {
      FocusManager.instance.primaryFocus?.unfocus();
      _clearTextEditing();
    }
    _bringElementToFront(model);
  }

  void _handleSelectableElementPointerDown(
    CanvasElementModel model,
    PointerDownEvent event,
  ) {
    if (event.buttons != kPrimaryButton ||
        !_documentLoaded ||
        _activeTool.value != _CanvasTool.select ||
        !_elements.contains(model)) {
      return;
    }
    _interactiveCanvasPointerIds.add(event.pointer);
    if (_toggleSelectionIfModifierPressed(model)) return;
    if (!model.active) _setActiveElement(null);
    FocusManager.instance.primaryFocus?.unfocus();
    _clearTextEditing();
    _bringElementToFront(model);
  }

  void _activateElement(CanvasElementModel model) {
    if (!_documentLoaded || _activeTool.value != _CanvasTool.select || !_elements.contains(model)) return;
    _clearTextEditing();
    _setActiveElement(model);
  }

  void _editTextBlock(TextBlockModel model) {
    if (!_documentLoaded || _placementEnabled || _penEnabled || _eraserEnabled || !_elements.contains(model)) {
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
    _setActiveElement(editing);
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
    _finishHistoryOperation();
  }

  void _clearElementEditing() {
    FocusManager.instance.primaryFocus?.unfocus();
    _clearTextEditing();
    _setActiveElement(null);
  }

  void _setActiveElement(CanvasElementModel? model) {
    if (identical(_activeElement, model)) return;
    setState(() {
      _activeElement?.active = false;
      _activeElement = model;
      model?.active = true;
      if (model != null) _editingChromeModel = model;
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

  // ---------- Element transforms ----------

  GlobalKey _selectionKey(Object model) => _selectionKeys.putIfAbsent(model, GlobalKey.new);

  void _moveSelectedChildren(CanvasElementModel dragged, Offset screenDelta) {
    if (!_documentLoaded ||
        _placementEnabled ||
        _penEnabled ||
        _eraserEnabled ||
        _selectionModifierPressed.value ||
        screenDelta == Offset.zero) {
      return;
    }

    final selectedBeforeWidgetPointer = _selectionBeforeWidgetPointer;
    final draggedWasSelected = selectedBeforeWidgetPointer.contains(dragged);
    if (draggedWasSelected) _setSelection(selectedBeforeWidgetPointer);

    final draggedSelected = draggedWasSelected || (_elements.contains(dragged) && dragged.selected);

    if (!draggedSelected) _clearSelection();

    final gridDelta = screenDelta / _canvasController.scale;
    final affected = _elements
        .where(
          (model) => identical(model, dragged) || draggedSelected && model.selected,
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
    if (!_documentLoaded || _placementEnabled || _penEnabled || _eraserEnabled) {
      return;
    }
    if (!_elements.contains(model)) return;
    model.resize(renderedSize, _localTransformDelta(model.rotation, screenDelta));
  }

  void _resizeCodeBlock(CodeBlockModel model, Offset localDelta) {
    if (!_documentLoaded || _placementEnabled || _penEnabled || _eraserEnabled) {
      return;
    }
    if (!_elements.contains(model)) return;
    model.size = Size(
      model.size.width + localDelta.dx,
      model.size.height + localDelta.dy,
    );
  }

  void _resizeMedia(MediaModel model, Offset screenDelta) {
    if (!_documentLoaded || _activeTool.value != _CanvasTool.select || !_elements.contains(model)) {
      return;
    }
    model.resizeBy(_localTransformDelta(model.rotation, screenDelta));
  }

  void _resizeShape(ShapeModel model, Offset screenDelta) {
    if (!_documentLoaded || _activeTool.value != _CanvasTool.select || !_elements.contains(model)) {
      return;
    }
    if (_selectionBeforeWidgetPointer.contains(model)) {
      _setSelection(_selectionBeforeWidgetPointer);
    }
    model.resizeBy(screenDelta / _canvasController.scale);
  }

  Offset _localTransformDelta(double rotation, Offset screenDelta) {
    final delta = screenDelta / _canvasController.scale;
    final angle = -rotation;
    final cosine = math.cos(angle);
    final sine = math.sin(angle);
    return Offset(
      delta.dx * cosine - delta.dy * sine,
      delta.dx * sine + delta.dy * cosine,
    );
  }

  void _rotateElement(RotatableCanvasElementModel model, double angle) {
    if (!_documentLoaded || _placementEnabled || _penEnabled || _eraserEnabled) {
      return;
    }
    if (!_elements.contains(model)) return;
    model.rotate(angle);
  }

  Offset _elementCenter(CanvasElementModel model) {
    final renderObject = _selectionKey(
      model,
    ).currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return Offset.zero;
    return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
  }

  // ---------- Element creation ----------

  void _addTextBlock(Offset position) {
    if (!_documentLoaded) return;
    final node = TextElementData(
      id: const Uuid().v4(),
      position: position,
      width: textNodeDefaultWidth,
      height: textNodeDefaultHeight,
      markdown: '',
      style: TextNodeStyle(
        fontFamily: 'Source Serif 4',
        color: colorToHex(BTheme.of(context).colors.textPrimary),
      ),
    );
    final model = TextBlockModel(node);

    _mountElement(model, requestFocus: true);
    _startTextEditing(model);
    _scheduleDocumentSave();
  }

  void _addMedia(Offset position) {
    if (!_documentLoaded) return;
    final model = _newMediaModel('')..data.position = position;
    _mountElement(model, requestFocus: true);
    _setActiveElement(model);
    _scheduleDocumentSave();
    _finishHistoryOperation();
  }

  CanvasElementModel _createElementModel(CanvasElementData data) {
    return switch (data) {
      final TextElementData data => TextBlockModel(data),
      final CodeElementData data => CodeBlockModel(data),
      final MediaElementData data => MediaModel(data, _attachmentStore),
      final ShapeElementData data => ShapeModel(data),
      final PenElementData data => PenStrokeModel(data),
      final ArrowElementData data => ArrowModel(data),
    };
  }

  void _mountElement(
    CanvasElementModel model, {
    bool requestFocus = false,
  }) {
    _elements.add(model);
    model.documentChanges.addListener(_scheduleDocumentSave);
    final child = switch (model) {
      final TextBlockModel text => _CanvasElementHost(
        key: _selectionKey(text),
        model: text,
        activeTool: _activeTool,
        modifierPressed: _selectionModifierPressed,
        onPointerDown: (event) => _handleTextBlockPointerDown(text, event),
        child: TextTool(
          model: text,
          attachmentStore: _attachmentStore,
          onEdit: () => _editTextBlock(text),
          onMove: (delta) => _moveSelectedChildren(text, delta),
          onResize: (size, delta) => _resizeTextBlock(text, size, delta),
        ),
      ),
      final CodeBlockModel code => _CanvasElementHost(
        key: _selectionKey(code),
        model: code,
        activeTool: _activeTool,
        modifierPressed: _selectionModifierPressed,
        onPointerDown: (event) => _handleCodeBlockPointerDown(code, event),
        child: CodeTool(
          model: code,
          onEdit: () => _editCodeBlock(code),
          onMove: (delta) => _moveSelectedChildren(code, delta),
          onResize: (delta) => _resizeCodeBlock(code, delta),
          onChangeBoundary: _finishHistoryOperation,
        ),
      ),
      final MediaModel media => _CanvasElementHost(
        key: _selectionKey(media),
        model: media,
        activeTool: _activeTool,
        modifierPressed: _selectionModifierPressed,
        onPointerDown: (event) => _handleSelectableElementPointerDown(media, event),
        child: MediaTool(
          model: media,
          onActivate: () => _activateElement(media),
          onMove: (delta) => _moveSelectedChildren(media, delta),
          onResize: (delta) => _resizeMedia(media, delta),
          onDeactivate: () {
            if (identical(_activeElement, media)) _setActiveElement(null);
          },
        ),
      ),
      final ShapeModel shape => _CanvasElementHost(
        key: _selectionKey(shape),
        model: shape,
        activeTool: _activeTool,
        modifierPressed: _selectionModifierPressed,
        onPointerDown: (event) => _handleSelectableElementPointerDown(shape, event),
        child: Shape(
          model: shape,
          onActivate: () => _activateElement(shape),
          onMove: (delta) => _moveSelectedChildren(shape, delta),
          onResize: (delta) => _resizeShape(shape, delta),
        ),
      ),
      final PenStrokeModel pen => _CanvasElementHost(
        key: _selectionKey(pen),
        model: pen,
        activeTool: _activeTool,
        modifierPressed: _selectionModifierPressed,
        onPointerDown: (event) => _handleStrokePointerDown(pen, event),
        child: PenStroke(
          model: pen,
          onMove: (delta) => _moveSelectedChildren(pen, delta),
        ),
      ),
      final ArrowModel arrow => _CanvasElementHost(
        key: _selectionKey(arrow),
        model: arrow,
        activeTool: _activeTool,
        modifierPressed: _selectionModifierPressed,
        onPointerDown: (event) => _handleArrowPointerDown(arrow, event),
        child: Arrow(model: arrow),
      ),
      _ => throw StateError('Unknown canvas element model'),
    };
    _canvasController.addChild(
      model.canvasPosition,
      child,
      id: model.data.id,
      childSize: model.canvasSize,
    );
    _editorFocusNode(model)?.addListener(_finishHistoryOperation);
    if (requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _editorFocusNode(model)?.requestFocus(),
      );
    }
  }

  // ---------- Drawing tools ----------

  void _handleCanvasPointerExit(PointerExitEvent event) {
    _canvasPointerPosition.value = null;
    if (_penEnabled) _penTool.onPointerExit(event);
  }

  void _handleCanvasPointerHover(PointerHoverEvent event) {
    _canvasPointerPosition.value = event.localPosition;
    if (_penEnabled && !_spaceHeld) _penTool.onPointerHover(event);
  }

  void _addCodeBlock(Offset position) {
    if (!_documentLoaded) return;
    final size = _fittedBlockSize(const Size(600, 400), codeBlockMinimumSize);
    final model = CodeBlockModel(
      CodeElementData(
        id: const Uuid().v4(),
        position: position,
        size: size,
        language: CodeLanguage.dart,
        source: '',
        title: '',
        showLineNumbers: true,
      ),
    );
    _mountElement(model, requestFocus: true);
    _setActiveElement(model);
    _scheduleDocumentSave();
    _finishHistoryOperation();
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

  void _addStroke(RawPenStroke rawStroke) {
    if (!_documentLoaded) return;
    final model = PenStrokeModel(
      positionStroke(
        rawStroke,
        id: const Uuid().v4(),
        canvasOffset: _canvasController.offset,
        canvasScale: _canvasController.scale,
      ),
    );
    _mountElement(model);
    _scheduleDocumentSave();
    _finishHistoryOperation();
  }

  void _addArrow(ArrowModel model) {
    if (!_documentLoaded) return;
    if (_arrowEnabled) setState(() => _activeTool.value = _CanvasTool.select);
    _mountElement(model);
    _setActiveElement(model);
    _scheduleDocumentSave();
    _finishHistoryOperation();
  }

  void _addShape(ShapeModel model) {
    if (!_documentLoaded) return;
    if (_shapeEnabled) setState(() => _activeTool.value = _CanvasTool.select);
    _mountElement(model);
    _setActiveElement(model);
    _scheduleDocumentSave();
    _finishHistoryOperation();
  }

  void _handleArrowPointerDown(
    ArrowModel model,
    PointerDownEvent event,
  ) {
    if (event.buttons != kPrimaryButton ||
        !_documentLoaded ||
        _placementEnabled ||
        _penEnabled ||
        _eraserEnabled ||
        _arrowEnabled ||
        !_elements.contains(model)) {
      return;
    }
    _interactiveCanvasPointerIds.add(event.pointer);
    if (_toggleSelectionIfModifierPressed(model)) return;
    _setActiveElement(model);
    _bringElementToFront(model);
    _clearTextEditing();
    _dragArrowPointer = event.pointer;
    _dragArrow = model;
  }

  void _finishArrowDrag({bool select = false}) {
    if (select) _dragArrow?.selected = true;
    _dragArrowPointer = null;
    _dragArrow = null;
    _finishHistoryOperation();
  }

  void _startArrowPointEdit() {
    _finishHistoryOperation();
    _clearSelection();
  }

  void _editArrowPoint(
    ArrowModel model,
    ArrowPoint point,
    Offset position,
  ) {
    if (!_documentLoaded || !identical(_activeElement, model) || !_elements.contains(model)) return;
    if (!model.setPoint(point, position)) return;
    _canvasController.updatePosition(model.data.id, model.canvasPosition);
  }

  void _handleStrokePointerDown(
    PenStrokeModel model,
    PointerDownEvent event,
  ) {
    if (event.buttons != kPrimaryButton ||
        !_documentLoaded ||
        _placementEnabled ||
        _penEnabled ||
        _eraserEnabled ||
        !_elements.contains(model)) {
      return;
    }
    _interactiveCanvasPointerIds.add(event.pointer);
    if (_toggleSelectionIfModifierPressed(model)) return;
    _clearElementEditing();
    _bringElementToFront(model);
  }

  // ---------- Editing commands ----------

  void _selectAll() {
    if (!_documentLoaded) return;
    for (final model in _elements) {
      model.selected = true;
    }
  }

  void _deleteSelected() {
    final targets = _elements.where((model) => model.selected).toList();
    if (targets.isEmpty && _activeElement != null) targets.add(_activeElement!);
    _removeElements(targets);
  }

  // ---------- Clipboard ----------

  bool get _editingElement {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null ||
        _elements.whereType<TextBlockModel>().any(
          (model) => model.focusNode.hasFocus,
        ) ||
        _elements.whereType<CodeBlockModel>().any(
          (model) => model.focusNode.hasFocus,
        ) ||
        _elements.whereType<MediaModel>().any(
          (model) => model.focusNode.hasFocus,
        );
  }

  List<CanvasElementModel> get _selectedInStackingOrder => _elements.where((model) => model.selected).toList();

  void _handleWebCopy(ClipboardWriteEvent event) => unawaited(_copySelection(event));

  void _handleWebCut(ClipboardWriteEvent event) => unawaited(_copySelection(event, cut: true));

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
      _pointerReference = (payload, _canvasPointerPosition.value);
      if (cut) _removeElements(selected);
    } on Object {
      _showProjectSnackBar(
        cut ? 'Could not cut canvas elements' : 'Could not copy canvas elements',
      );
    }
  }

  Future<void> _pasteSelection(Future<ClipboardReader>? readerFuture) async {
    try {
      final read = widget.readClipboard;
      late final CanvasClipboardSnapshot clipboard;
      try {
        clipboard = read != null ? await read() : await readCanvasClipboard(await readerFuture!);
      } on FormatException {
        return;
      }
      final text = clipboard.text;
      final elements = text == null ? null : decodeCanvasClipboard(text);
      if (elements == null) {
        if (clipboard.image case final image?) {
          await _pasteImage(image);
        } else if (text?.trim() case final url? when isSupportedMediaUrl(url)) {
          _pasteMediaUrl(url);
        }
        return;
      }
      if (!mounted || !_documentLoaded) return;
      final payload = text!;

      final pointer = _canvasPointerPosition.value;
      final placeAtPointer = pointer != null && (payload, pointer) != _pointerReference;
      final pasted = [
        for (final element in elements) _createElementModel(element.copy(id: const Uuid().v4())),
      ];
      if (placeAtPointer) {
        final bounds = pasted
            .map((model) => model.canvasPosition & model.canvasSize)
            .reduce((bounds, next) => bounds.expandToInclude(next));
        _pasteOffset = _canvasController.offset + pointer / _canvasController.scale - bounds.center;
      } else if (_lastPastedPayload != payload) {
        _pasteOffset = payload == _cutPayload ? Offset.zero : const Offset(24, 24) / _canvasController.scale;
      } else {
        _pasteOffset += const Offset(24, 24) / _canvasController.scale;
      }
      _lastPastedPayload = payload;
      _pointerReference = (payload, pointer);
      for (final model in pasted) {
        model.moveBy(_pasteOffset);
        _mountElement(model);
      }
      _clearTextEditing();
      _setActiveElement(null);
      _setSelection(pasted.toSet());
      _scheduleDocumentSave();
      _finishHistoryOperation();
    } on Object {
      _showProjectSnackBar('Could not paste canvas elements');
    }
  }

  Future<void> _pasteImage(ClipboardImage image) async {
    final model = _newMediaModel('');
    try {
      await model.setDeviceImage(image.bytes, image.extension);
    } on FormatException {
      model.dispose();
      return;
    } on Object {
      model.dispose();
      rethrow;
    }
    if (!mounted || !_documentLoaded) {
      model.dispose();
      return;
    }
    _placePastedMedia(model);
  }

  void _pasteMediaUrl(String url) {
    if (!mounted || !_documentLoaded) return;
    _placePastedMedia(_newMediaModel(url));
  }

  MediaModel _newMediaModel(String url) => MediaModel(
    MediaElementData(
      id: const Uuid().v4(),
      position: Offset.zero,
      width: mediaNodeDefaultWidth,
      url: url,
    ),
    _attachmentStore,
  );

  void _placePastedMedia(MediaModel model) {
    final screenPosition = _canvasPointerPosition.value ?? _canvasController.canvasSize.center(Offset.zero);
    final center = _screenToCanvas(screenPosition);
    model.data.position = center - model.canvasSize.center(Offset.zero);
    _clearTextEditing();
    _setActiveElement(null);
    _clearSelection();
    model.selected = true;
    _mountElement(model);
    _scheduleDocumentSave();
    _finishHistoryOperation();
  }

  // ---------- Erasing ----------

  void _eraseAt(Offset globalPosition) {
    final hits = <CanvasElementModel>[];
    for (final model in _elements) {
      final renderObject = _selectionKeys[model]?.currentContext?.findRenderObject();
      if (renderObject is RenderBox &&
          renderObject.hitTest(
            BoxHitTestResult(),
            position: renderObject.globalToLocal(globalPosition),
          )) {
        hits.add(model);
      }
    }
    _removeElements(hits, finishHistory: false);
  }

  void _removeElements(
    Iterable<CanvasElementModel> models, {
    bool finishHistory = true,
  }) {
    if (!_documentLoaded) return;
    final modelsToDispose = models.where(_elements.contains).toList();
    if (modelsToDispose.isEmpty) return;

    final removesEditingElement = modelsToDispose.any(
      (model) => identical(model, _editingTextBlock) || identical(model, _editingChromeModel),
    );
    if (removesEditingElement) {
      _clearTextEditing();
      setState(() => _editingChromeModel = null);
    }
    if (modelsToDispose.contains(_activeElement)) _setActiveElement(null);
    for (final model in modelsToDispose) {
      _editorFocusNode(model)?.unfocus();
      _editorFocusNode(model)?.removeListener(_finishHistoryOperation);
      _canvasController.removeChild(model.data.id);
      _elements.remove(model);
      _selectionKeys.remove(model);
      _selectionBeforeDrag.remove(model);
      _selectionBeforeWidgetPointer.remove(model);
      model.documentChanges.removeListener(_scheduleDocumentSave);
    }
    if (_selectionBeforeWidgetPointer.isEmpty) _widgetPointer = null;
    if (modelsToDispose.contains(_dragArrow)) _finishArrowDrag();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final model in modelsToDispose) {
        model.dispose();
      }
    });
    _scheduleDocumentSave();
    if (finishHistory) _finishHistoryOperation();
  }

  // ---------- Settings and project transfer ----------

  void _showSettingsDialog() {
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: BTheme.of(context).colors.scrim,
        builder: (_) => SettingsDialog(
          canvasBackgroundKind: _canvasBackgroundKind,
          noIcons: _noIcons,
          onCanvasBackgroundChanged: _setCanvasBackground,
          onNoIconsChanged: _setNoIcons,
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
      final dirtyFlush = _documentDirty ? _enqueueDocumentSave(throwOnFailure: true) : null;
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
    final collisionPaths = currentPaths.intersection(importedPaths).toList()..sort();
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
      _resetHistory();
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
    _shapeTool.cancel();
    _activeTool.value = _CanvasTool.select;
    _activeElement = null;
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
      model.documentChanges.removeListener(_scheduleDocumentSave);
      _editorFocusNode(model)?.removeListener(_finishHistoryOperation);
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
    _finishHistoryOperation();
  }

  // ---------- Keyboard commands ----------

  bool _handleKeyEvent(KeyEvent event) {
    if (!_documentLoaded) return false;
    _selectionModifierPressed.value = Theme.of(context).platform == TargetPlatform.macOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;
    final unmodifiedKeyDown =
        event is KeyDownEvent &&
        ModalRoute.of(context)?.isCurrent != false &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isShiftPressed;
    if (unmodifiedKeyDown && event.logicalKey == LogicalKeyboardKey.escape) {
      if (_editingElement || _activeElement != null) {
        _clearElementEditing();
        _clearSelection();
      } else {
        _toggleTool(_activeTool.value);
      }
      return true;
    }
    if (_editingElement) return false;
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        _selectionModifierPressed.value &&
        event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _redo();
      } else {
        _undo();
      }
      return true;
    }
    if (event is KeyDownEvent && _selectionModifierPressed.value && _clipboardEvents == null) {
      if (event.logicalKey == LogicalKeyboardKey.keyC || event.logicalKey == LogicalKeyboardKey.keyX) {
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
        final read = widget.readClipboard;
        final clipboard = SystemClipboard.instance;
        if (read == null && clipboard == null) {
          _showProjectSnackBar('Could not paste canvas elements');
          return true;
        }
        unawaited(_pasteSelection(read != null ? null : clipboard!.read()));
        return true;
      }
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyA && _selectionModifierPressed.value) {
      _selectAll();
      return true;
    }
    if (unmodifiedKeyDown) {
      final tool = switch (event.logicalKey) {
        LogicalKeyboardKey.keyT => _CanvasTool.text,
        LogicalKeyboardKey.keyC => _CanvasTool.code,
        LogicalKeyboardKey.keyM => _CanvasTool.media,
        LogicalKeyboardKey.keyS => _CanvasTool.shape,
        LogicalKeyboardKey.keyP => _CanvasTool.pen,
        LogicalKeyboardKey.keyE => _CanvasTool.eraser,
        LogicalKeyboardKey.keyA => _CanvasTool.arrow,
        _ => null,
      };
      if (tool != null) {
        _toggleTool(tool);
        return true;
      }
    }
    final deletionKey =
        event.logicalKey == LogicalKeyboardKey.delete ||
        (Theme.of(context).platform == TargetPlatform.macOS && event.logicalKey == LogicalKeyboardKey.backspace);
    if ((event is KeyDownEvent || event is KeyRepeatEvent) && deletionKey) {
      _deleteSelected();
      return true;
    }
    if ((!_penEnabled && !_eraserEnabled) || event.logicalKey != LogicalKeyboardKey.space) {
      return false;
    }
    final held = event is! KeyUpEvent;
    if (_spaceHeld != held) setState(() => _spaceHeld = held);
    return true;
  }

  // ---------- Document persistence ----------

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
      _resetHistory();
      if (mounted) setState(() {});
    } on Object {
      _documentLoaded = true;
      _resetHistory();
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
    _noteHistoryChange();
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
      (_) => throwOnFailure ? _persistDocument(snapshot) : _saveDocument(snapshot),
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

  // ---------- History ----------

  String _captureHistory() => jsonEncode(_currentDocument().toJson());

  void _resetHistory() {
    _undoHistory.clear();
    _redoHistory.clear();
    _historyCurrent = _captureHistory();
    _historyOperationActive = false;
  }

  void _noteHistoryChange() {
    if (_historyOperationActive) return;
    final current = _historyCurrent;
    if (current == null) return;
    if (_captureHistory() != current) {
      _historyOperationActive = true;
    }
  }

  void _finishHistoryOperation() {
    if (!_historyOperationActive || !_documentLoaded) {
      return;
    }
    final previous = _historyCurrent;
    final current = _captureHistory();
    _historyOperationActive = false;
    if (previous == null || previous == current) return;
    _undoHistory.add(previous);
    if (_undoHistory.length > _historyLimit) _undoHistory.removeAt(0);
    _redoHistory.clear();
    _historyCurrent = current;
  }

  void _undo() {
    _finishHistoryOperation();
    final current = _historyCurrent;
    if (current == null || _undoHistory.isEmpty) return;
    _redoHistory.add(current);
    _restoreHistory(_undoHistory.removeLast());
  }

  void _redo() {
    _finishHistoryOperation();
    final current = _historyCurrent;
    if (current == null || _redoHistory.isEmpty) return;
    _undoHistory.add(current);
    _restoreHistory(_redoHistory.removeLast());
  }

  void _restoreHistory(String entry) {
    _historyCurrent = entry;
    _historyOperationActive = false;
    _replaceLiveModels(CanvasDocument.fromJson(jsonDecode(entry)));
    _scheduleDocumentSave();
  }

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final geo = theme.geo;
    final editingChromeModel = _editingChromeModel;
    final activeTextBlock = _activeTextBlock;
    final activeCodeBlock = _activeCodeBlock;
    final activeShape = _activeShape;
    final activeArrow = _activeArrow;
    return Scaffold(
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: !_documentLoaded,
            child: MouseRegion(
              cursor: !_spaceHeld && (_penEnabled || _eraserEnabled) ? SystemMouseCursors.none : MouseCursor.defer,
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
                  mousePanButtons: kSecondaryMouseButton | kMiddleMouseButton | (_spaceHeld ? kPrimaryMouseButton : 0),
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
                    preview: preview,
                    canvasOffset: _canvasController.offset,
                    canvasScale: _canvasController.scale,
                  ),
                ),
              ),
            ),
          if (_shapeTool.preview case final preview?)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('shape-preview'),
                  painter: ShapePreviewPainter(
                    preview: preview,
                    canvasOffset: _canvasController.offset,
                    canvasScale: _canvasController.scale,
                  ),
                ),
              ),
            ),
          if (_penEnabled)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('pen-preview'),
                  painter: PenPreviewPainter(
                    tool: _penTool,
                    color: colors.accent,
                  ),
                ),
              ),
            ),
          if (_eraserEnabled && !_spaceHeld)
            ValueListenableBuilder<Offset?>(
              valueListenable: _canvasPointerPosition,
              builder: (context, pointer, child) {
                if (pointer == null) return const SizedBox.shrink();
                return Positioned(
                  key: const ValueKey('eraser-cursor'),
                  left: pointer.dx - 4,
                  top: pointer.dy - 9,
                  child: IgnorePointer(
                    child: Icon(
                      LucideIcons.eraser,
                      color: colors.accent,
                      size: 20,
                    ),
                  ),
                );
              },
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
                followerAnchor: Alignment.topRight,
                offset: const Offset(-10, 0),
                child: SizedBox.fromSize(
                  size: ElementTransformControls.size,
                  child: Overlay.wrap(
                    clipBehavior: Clip.none,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      reverseDuration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: _textEditingChromeTransition,
                      child: switch (_activeElement) {
                        final CanvasElementModel editing => ListenableBuilder(
                          key: ValueKey(editing.data.id),
                          listenable: editing,
                          builder: (context, child) => IgnorePointer(
                            ignoring: !editing.active,
                            child: child,
                          ),
                          child: ElementTransformControls(
                            key: ValueKey(editing.data.id),
                            elementName: editing.data.type,
                            rotation: switch (editing) {
                              final RotatableCanvasElementModel model => model.rotation,
                              _ => 0,
                            },
                            tapRegionGroupId: editing is MediaModel ? editing : null,
                            onMove: (delta) => _moveSelectedChildren(editing, delta),
                            onRotate: switch (editing) {
                              final RotatableCanvasElementModel model when model.canRotate => (angle) => _rotateElement(
                                model,
                                angle,
                              ),
                              _ => null,
                            },
                            onDelete: () => _removeElements([editing]),
                            onTransformStart: () {
                              if (editing is TextBlockModel) {
                                _clearTextEditing();
                              } else {
                                _finishHistoryOperation();
                              }
                            },
                            onTransformEnd: _finishHistoryOperation,
                            rotationCenter: () => _elementCenter(editing),
                          ),
                        ),
                        _ => const SizedBox(
                          key: ValueKey('text-editing-chrome-hidden'),
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ),
          if (activeArrow != null)
            Positioned.fill(
              child: ListenableBuilder(
                listenable: Listenable.merge([activeArrow, _canvasController]),
                builder: (context, _) => ArrowEditor(
                  model: activeArrow,
                  canvasOffset: _canvasController.offset,
                  canvasScale: _canvasController.scale,
                  onChangeStart: _startArrowPointEdit,
                  onPointChanged: (point, position) => _editArrowPoint(activeArrow, point, position),
                  onChangeEnd: _finishHistoryOperation,
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 12),
                child: ZoomControl(controller: _canvasController),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BContainer(
                    key: const ValueKey('toolbar-surface'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Place text',
                          child: ToolbarButton(
                            key: const ValueKey('toolbar-text'),
                            selected: _activeTool.value == _CanvasTool.text,
                            onPressed: () => _toggleTool(_CanvasTool.text),
                            child: _toolbarContent(
                              'Text',
                              LucideIcons.type,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Place code block',
                          child: ToolbarButton(
                            key: const ValueKey('toolbar-code'),
                            selected: _activeTool.value == _CanvasTool.code,
                            onPressed: () => _toggleTool(_CanvasTool.code),
                            child: _toolbarContent(
                              'Code',
                              LucideIcons.codeXml,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Place media',
                          child: ToolbarButton(
                            key: const ValueKey('toolbar-media'),
                            selected: _activeTool.value == _CanvasTool.media,
                            onPressed: () => _toggleTool(_CanvasTool.media),
                            child: _toolbarContent(
                              'Media',
                              LucideIcons.image,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Draw rounded rectangle',
                          child: ToolbarButton(
                            key: const ValueKey('toolbar-shape'),
                            selected: _shapeEnabled,
                            onPressed: () => _toggleTool(_CanvasTool.shape),
                            child: _toolbarContent(
                              'Rect',
                              LucideIcons.squareRoundCorner,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Draw with pen',
                          child: ToolbarButton(
                            key: const ValueKey('toolbar-draw'),
                            selected: _penEnabled,
                            onPressed: () => _toggleTool(_CanvasTool.pen),
                            child: _toolbarContent(
                              'Draw',
                              LucideIcons.pencil,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Erase elements',
                          child: ToolbarButton(
                            key: const ValueKey('toolbar-erase'),
                            selected: _eraserEnabled,
                            onPressed: () => _toggleTool(_CanvasTool.eraser),
                            child: _toolbarContent(
                              'Erase',
                              LucideIcons.eraser,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Draw an arrow',
                          child: ToolbarButton(
                            key: const ValueKey('toolbar-arrow'),
                            selected: _arrowEnabled,
                            onPressed: () => _toggleTool(_CanvasTool.arrow),
                            child: _toolbarContent(
                              'Arrow',
                              LucideIcons.arrowUpRight,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    BContainer(
                      key: const ValueKey('settings-button-surface'),
                      child: IconButton(
                        key: const ValueKey('settings-button'),
                        tooltip: 'Settings',
                        onPressed: _showSettingsDialog,
                        style:
                            _toolbarButtonStyle(
                              colors,
                              geo,
                            ).copyWith(
                              padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
                            ),
                        icon: const Icon(LucideIcons.settings),
                      ),
                    ),
                    Flexible(
                      child: ToolOptions(
                        child: activeTextBlock != null
                            ? Listener(
                                onPointerDown: (_) => _clearTextEditing(),
                                child: TextToolSettings(
                                  key: ValueKey(
                                    'text-settings-${activeTextBlock.node.id}',
                                  ),
                                  model: activeTextBlock,
                                  onChangeBoundary: _finishHistoryOperation,
                                  colorPickerExpanded: _textColorPickerExpanded,
                                  onColorPickerExpandedChanged: (expanded) => setState(
                                    () => _textColorPickerExpanded = expanded,
                                  ),
                                ),
                              )
                            : activeCodeBlock != null
                            ? CodeToolSettings(
                                key: ValueKey(
                                  'code-settings-${activeCodeBlock.data.id}',
                                ),
                                model: activeCodeBlock,
                                onChangeBoundary: _finishHistoryOperation,
                              )
                            : activeShape != null
                            ? ListenableBuilder(
                                key: const ValueKey('shape-settings-panel'),
                                listenable: activeShape,
                                builder: (context, _) => _ShapeSettings(
                                  kind: activeShape.kind,
                                  strokeColor: activeShape.strokeColor,
                                  fillColor: activeShape.fillColor,
                                  strokeWidth: activeShape.strokeWidth,
                                  outlineColorPickerExpanded: _shapeOutlineColorPickerExpanded,
                                  onKindChanged: (kind) => _editElement(activeShape, () => activeShape.kind = kind),
                                  onStrokeColorChanged: (color) =>
                                      _editElement(activeShape, () => activeShape.strokeColor = color),
                                  onFillColorChanged: (color) =>
                                      _editElement(activeShape, () => activeShape.fillColor = color),
                                  onStrokeWidthChanged: (width) =>
                                      _editElement(activeShape, () => activeShape.strokeWidth = width),
                                  onOutlineColorPickerExpandedChanged: (expanded) => setState(
                                    () => _shapeOutlineColorPickerExpanded = expanded,
                                  ),
                                ),
                              )
                            : activeArrow != null
                            ? ListenableBuilder(
                                key: const ValueKey('arrow-settings-panel'),
                                listenable: activeArrow,
                                builder: (context, _) => _ArrowSettings(
                                  color: activeArrow.color,
                                  strokeStyle: activeArrow.strokeStyle,
                                  strokeWidth: activeArrow.strokeWidth,
                                  colorPickerExpanded: _arrowColorPickerExpanded,
                                  onColorChanged: (color) => _editElement(activeArrow, () => activeArrow.color = color),
                                  onStrokeStyleChanged: (style) =>
                                      _editElement(activeArrow, () => activeArrow.strokeStyle = style),
                                  onStrokeWidthChanged: (width) =>
                                      _editElement(activeArrow, () => activeArrow.strokeWidth = width),
                                  onColorPickerExpandedChanged: (expanded) =>
                                      setState(() => _arrowColorPickerExpanded = expanded),
                                ),
                              )
                            : _penEnabled
                            ? _StrokeSettings(
                                key: const ValueKey('draw-settings-panel'),
                                color: _penColor,
                                width: _penWidth,
                                colorPickerExpanded: _penColorPickerExpanded,
                                onColorChanged: _setPenColor,
                                onColorPickerExpandedChanged: (expanded) => setState(
                                  () => _penColorPickerExpanded = expanded,
                                ),
                                onWidthChanged: _setPenWidth,
                              )
                            : _shapeEnabled
                            ? ListenableBuilder(
                                key: const ValueKey('shape-settings-panel'),
                                listenable: _shapeTool,
                                builder: (context, _) => _ShapeSettings(
                                  kind: _shapeTool.kind,
                                  strokeColor: _shapeTool.strokeColor,
                                  fillColor: _shapeTool.fillColor,
                                  strokeWidth: _shapeTool.strokeWidth,
                                  outlineColorPickerExpanded: _shapeOutlineColorPickerExpanded,
                                  onKindChanged: _shapeTool.setKind,
                                  onStrokeColorChanged: _setShapeStrokeColor,
                                  onFillColorChanged: _shapeTool.setFillColor,
                                  onStrokeWidthChanged: _shapeTool.setStrokeWidth,
                                  onOutlineColorPickerExpandedChanged: (expanded) => setState(
                                    () => _shapeOutlineColorPickerExpanded = expanded,
                                  ),
                                ),
                              )
                            : _arrowEnabled
                            ? ListenableBuilder(
                                key: const ValueKey('arrow-settings-panel'),
                                listenable: _arrowTool,
                                builder: (context, _) => _ArrowSettings(
                                  color: _arrowTool.color,
                                  strokeStyle: _arrowTool.strokeStyle,
                                  strokeWidth: _arrowTool.strokeWidth,
                                  colorPickerExpanded: _arrowColorPickerExpanded,
                                  onColorChanged: _setArrowColor,
                                  onStrokeStyleChanged: _arrowTool.setStrokeStyle,
                                  onStrokeWidthChanged: _arrowTool.setStrokeWidth,
                                  onColorPickerExpandedChanged: (expanded) =>
                                      setState(() => _arrowColorPickerExpanded = expanded),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarContent(String label, IconData icon) =>
      _noIcons ? Text(label) : Icon(icon, size: 20, semanticLabel: label);
}

// ---------- Tool settings ----------

class _ArrowSettings extends StatelessWidget {
  const _ArrowSettings({
    required this.color,
    required this.strokeStyle,
    required this.strokeWidth,
    required this.colorPickerExpanded,
    required this.onColorChanged,
    required this.onStrokeStyleChanged,
    required this.onStrokeWidthChanged,
    required this.onColorPickerExpandedChanged,
  });

  final Color color;
  final ArrowStrokeStyle strokeStyle;
  final double strokeWidth;
  final bool colorPickerExpanded;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<ArrowStrokeStyle> onStrokeStyleChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<bool> onColorPickerExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Style', style: theme.typo.label),
        const SizedBox(height: 6),
        Wrap(
          children: [
            for (final option in ArrowStrokeStyle.values)
              Tooltip(
                message: option == ArrowStrokeStyle.solid ? 'Solid' : 'Dashed',
                child: ToolbarButton(
                  key: ValueKey('arrow-style-${option.name}'),
                  iconOnly: true,
                  selected: option == strokeStyle,
                  onPressed: () => onStrokeStyleChanged(option),
                  child: ArrowStrokeStyleIcon(style: option),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _StrokeSettings(
          color: color,
          width: strokeWidth,
          colorPickerExpanded: colorPickerExpanded,
          onColorChanged: onColorChanged,
          onColorPickerExpandedChanged: onColorPickerExpandedChanged,
          onWidthChanged: onStrokeWidthChanged,
        ),
      ],
    );
  }
}

class _ShapeSettings extends StatelessWidget {
  const _ShapeSettings({
    required this.kind,
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
    required this.outlineColorPickerExpanded,
    required this.onKindChanged,
    required this.onStrokeColorChanged,
    required this.onFillColorChanged,
    required this.onStrokeWidthChanged,
    required this.onOutlineColorPickerExpandedChanged,
  });

  final ShapeKind kind;
  final Color strokeColor;
  final Color? fillColor;
  final double strokeWidth;
  final bool outlineColorPickerExpanded;
  final ValueChanged<ShapeKind> onKindChanged;
  final ValueChanged<Color> onStrokeColorChanged;
  final ValueChanged<Color?> onFillColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<bool> onOutlineColorPickerExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Shape', style: theme.typo.label),
        const SizedBox(height: 6),
        SizedBox(
          width: 120,
          child: Wrap(
            children: [
              for (final option in ShapeKind.values)
                Tooltip(
                  message: option.label,
                  child: ToolbarButton(
                    key: ValueKey('shape-option-${option.name}'),
                    iconOnly: true,
                    selected: option == kind,
                    onPressed: () => onKindChanged(option),
                    child: Icon(
                      _shapeIcon(option),
                      semanticLabel: option.label,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text('Outline', style: theme.typo.label),
        const SizedBox(height: 6),
        ColorControl(
          color: strokeColor,
          expanded: outlineColorPickerExpanded,
          onChanged: onStrokeColorChanged,
          onExpandedChanged: onOutlineColorPickerExpandedChanged,
        ),
        const SizedBox(height: 10),
        Text('Fill', style: theme.typo.label),
        const SizedBox(height: 6),
        _ColorSwatches(
          selectedColor: fillColor,
          keyPrefix: 'shape-fill',
          allowNone: true,
          onColorChanged: onFillColorChanged,
        ),
        const SizedBox(height: 10),
        Text('Width', style: theme.typo.label),
        DiscreteSlider(
          value: strokeWidth,
          onChanged: onStrokeWidthChanged,
        ),
      ],
    );
  }
}

IconData _shapeIcon(ShapeKind kind) => switch (kind) {
  ShapeKind.rectangle => LucideIcons.square,
  ShapeKind.roundedRectangle => LucideIcons.squareRoundCorner,
  ShapeKind.ellipse => LucideIcons.circle,
  ShapeKind.diamond => LucideIcons.diamond,
  ShapeKind.triangle => LucideIcons.triangle,
  ShapeKind.hexagon => LucideIcons.hexagon,
};

class _StrokeSettings extends StatelessWidget {
  const _StrokeSettings({
    required this.color,
    required this.width,
    required this.colorPickerExpanded,
    required this.onColorChanged,
    required this.onColorPickerExpandedChanged,
    required this.onWidthChanged,
    super.key,
  });

  final Color color;
  final double width;
  final bool colorPickerExpanded;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<bool> onColorPickerExpandedChanged;
  final ValueChanged<double> onWidthChanged;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Color', style: theme.typo.label),
        const SizedBox(height: 6),
        ColorControl(
          color: color,
          expanded: colorPickerExpanded,
          onChanged: onColorChanged,
          onExpandedChanged: onColorPickerExpandedChanged,
        ),
        const SizedBox(height: 10),
        Text('Width', style: theme.typo.label),
        DiscreteSlider(
          value: width,
          onChanged: onWidthChanged,
        ),
      ],
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({
    required this.selectedColor,
    required this.keyPrefix,
    required this.onColorChanged,
    this.allowNone = false,
  });

  final Color? selectedColor;
  final String keyPrefix;
  final ValueChanged<Color?> onColorChanged;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final colors = BTheme.of(context).colors;
    return Wrap(
      children: [
        if (allowNone)
          Tooltip(
            message: 'No fill',
            child: ToolbarButton(
              key: ValueKey('$keyPrefix-none'),
              iconOnly: true,
              selected: selectedColor == null,
              onPressed: () => onColorChanged(null),
              child: const Icon(LucideIcons.ban, semanticLabel: 'No fill'),
            ),
          ),
        for (final swatch in _toolColorSwatches)
          Tooltip(
            message: swatch.label,
            child: Semantics(
              button: true,
              selected: selectedColor == swatch.color,
              label: swatch.label,
              child: InkWell(
                key: ValueKey('$keyPrefix-${swatch.label.toLowerCase()}'),
                customBorder: const CircleBorder(),
                onTap: () => onColorChanged(swatch.color),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: swatch.color,
                      border: Border.all(
                        color: selectedColor == swatch.color ? colors.focusRing : colors.borderSubtle,
                        width: selectedColor == swatch.color ? 2 : 1,
                      ),
                    ),
                    child: const SizedBox.square(dimension: 22),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------- Selection chrome ----------

class _CanvasElementHost extends StatelessWidget {
  const _CanvasElementHost({
    required this.model,
    required this.activeTool,
    required this.modifierPressed,
    required this.onPointerDown,
    required this.child,
    super.key,
  });

  final CanvasElementModel model;
  final ValueListenable<_CanvasTool> activeTool;
  final ValueListenable<bool> modifierPressed;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final target = CompositedTransformTarget(link: model.layerLink, child: child);
    final listener = Listener(
      onPointerDown: onPointerDown,
      child: ListenableBuilder(
        listenable: Listenable.merge([activeTool, modifierPressed]),
        builder: (context, child) => AbsorbPointer(
          absorbing: activeTool.value != _CanvasTool.select || modifierPressed.value && model is! PenStrokeModel,
          child: child,
        ),
        child: target,
      ),
    );
    return switch (model) {
      final RotatableCanvasElementModel rotationModel => ListenableBuilder(
        listenable: rotationModel,
        builder: (context, child) => Transform.rotate(
          angle: rotationModel.rotation,
          child: child,
        ),
        child: listener,
      ),
      _ => listener,
    };
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
      (states) => states.contains(WidgetState.focused) ? BorderSide(color: colors.focusRing) : BorderSide.none,
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: geo.radiusSmall),
    ),
  );
}
