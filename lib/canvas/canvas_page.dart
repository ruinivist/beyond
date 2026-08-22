import 'dart:async';
import 'dart:math' as math;

import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/tools/code_block/code_block.dart';
import 'package:beyond/canvas/tools/pen/pen_tool.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/canvas/tools/text/text_node.dart';
import 'package:beyond/foundation/control_surface.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/widgets/settings_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:scribble/scribble.dart';
import 'package:uuid/uuid.dart';

class CanvasPage extends StatefulWidget {
  const CanvasPage({this.attachmentStore, super.key});

  final AttachmentStore? attachmentStore;

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final _canvasController = LazyCanvasController(
    buildCacheExtent: const Offset(600, 400),
  );
  CanvasBackgroundKind _canvasBackgroundKind = CanvasBackgroundKind.dotGrid;
  final CanvasDocumentStore _documentStore = CanvasDocumentStore();
  late final AttachmentStore _attachmentStore =
      widget.attachmentStore ?? createAttachmentStore();
  final _codeBlocks = <CodeBlockModel, ({CanvasChildId id, Offset position})>{};
  final _textBlocks = <TextBlockModel, CanvasChildId>{};
  TextBlockModel? _editingTextBlock;
  TextBlockModel? _editingChromeModel;
  final ValueNotifier<bool> _selectionModifierPressed = ValueNotifier(false);
  final _strokes = <PenStrokeModel, CanvasChildId>{};
  final _interactiveCanvasPointerIds = <int>{};
  final _selectionBeforeWidgetPointer = <Object>{};
  final _selectionKeys = <Object, GlobalKey>{};
  final _selectionBeforeDrag = <Object>{};
  int? _widgetPointer;
  int? _dragSelectionPointer;
  Offset? _dragSelectionStart;
  Offset? _dragSelectionEnd;
  var _toggleDragSelection = false;
  Timer? _saveTimer;
  Future<void> _saveQueue = Future<void>.value();
  bool _documentDirty = false;
  bool _documentLoaded = false;
  late final PenTool _penTool;
  var _penEnabled = false;
  var _textPlacementEnabled = false;
  var _spaceHeld = false;

  @override
  void initState() {
    super.initState();
    _penTool = PenTool(onStroke: _addStroke);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    unawaited(_restoreDocument());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colors = BTheme.of(context).colors;
    _canvasController.background = _canvasBackgroundKind.build(colors);
    _penTool.setColor(colors.accent);
  }

  Offset _viewportCenter() {
    final viewport = _canvasController.canvasSize;
    return _canvasController.offset +
        Offset(viewport.width, viewport.height) / (2 * _canvasController.scale);
  }

  void _toggleTextPlacement() {
    if (!_documentLoaded) return;
    if (!_textPlacementEnabled) _clearTextEditing();
    setState(() {
      _textPlacementEnabled = !_textPlacementEnabled;
      _penEnabled = false;
      _spaceHeld = false;
    });
    if (_textPlacementEnabled) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _handleCanvasPointerDown(PointerDownEvent event) {
    if (!_documentLoaded || event.buttons != kPrimaryButton) return;
    final onInteractiveChild = _interactiveCanvasPointerIds.remove(
      event.pointer,
    );
    if (_textPlacementEnabled) {
      setState(() => _textPlacementEnabled = false);
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
    FocusManager.instance.primaryFocus?.unfocus();
    _clearTextEditing();
    _selectionBeforeDrag
      ..clear()
      ..addAll(_selectedModels());
    _toggleDragSelection = _selectionModifierPressed.value;
    if (!_toggleDragSelection) _clearSelection();
    if (event.kind != PointerDeviceKind.mouse || _penEnabled) return;
    setState(() {
      _dragSelectionPointer = event.pointer;
      _dragSelectionStart = event.localPosition;
      _dragSelectionEnd = event.localPosition;
    });
  }

  void _handleCanvasPointerMove(PointerMoveEvent event) {
    if (event.pointer != _dragSelectionPointer) return;
    _updateDragSelection(event.localPosition);
  }

  void _handleCanvasPointerUp(PointerUpEvent event) {
    _finishWidgetPointer(event.pointer);
    if (event.pointer != _dragSelectionPointer) return;
    _updateDragSelection(event.localPosition);
    _finishDragSelection();
  }

  void _handleCanvasPointerCancel(PointerCancelEvent event) {
    _finishWidgetPointer(event.pointer);
    if (event.pointer != _dragSelectionPointer) return;
    for (final model in _textBlocks.keys) {
      model.selected = _selectionBeforeDrag.contains(model);
    }
    for (final model in _codeBlocks.keys) {
      model.selected = _selectionBeforeDrag.contains(model);
    }
    for (final model in _strokes.keys) {
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

    bool selected(ChangeNotifier model, String id) {
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

    for (final entry in _textBlocks.entries) {
      entry.key.selected = selected(entry.key, entry.value);
    }
    for (final entry in _codeBlocks.entries) {
      entry.key.selected = selected(entry.key, entry.value.id);
    }
    for (final entry in _strokes.entries) {
      entry.key.selected = selected(entry.key, entry.value);
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
    if (event.buttons != kPrimaryButton) return;
    _interactiveCanvasPointerIds.add(event.pointer);
    if (!_documentLoaded || _textPlacementEnabled || _penEnabled) return;
    final entry = _codeBlocks[model];
    if (entry == null) return;
    if (_selectionModifierPressed.value) {
      model.selected = !model.selected;
      return;
    }
    _clearTextEditing();
    _bringBlockToFront(entry.id);
  }

  void _handleTextBlockPointerDown(
    TextBlockModel model,
    PointerDownEvent event,
  ) {
    if (event.buttons != kPrimaryButton) return;
    _interactiveCanvasPointerIds.add(event.pointer);
    if (_textPlacementEnabled || _penEnabled) return;
    if (!_textBlocks.containsKey(model)) return;
    if (_selectionModifierPressed.value) {
      model.selected = !model.selected;
      return;
    }
    final canvasId = _textBlocks.remove(model);
    if (!model.editing) {
      FocusManager.instance.primaryFocus?.unfocus();
      _clearTextEditing();
    }
    _textBlocks[model] = canvasId!;
    _bringBlockToFront(canvasId);
    _scheduleDocumentSave();
  }

  void _editTextBlock(TextBlockModel model) {
    if (!_documentLoaded ||
        _textPlacementEnabled ||
        _penEnabled ||
        !_textBlocks.containsKey(model)) {
      return;
    }
    _startTextEditing(model);
    model.focusNode.requestFocus();
  }

  void _bringBlockToFront(String id) {
    _canvasController.bringToFront(id);
  }

  void _startTextEditing(TextBlockModel editing) {
    setState(() {
      _editingTextBlock = editing;
      _editingChromeModel = editing;
      for (final model in _textBlocks.keys) {
        model.editing = identical(model, editing);
      }
    });
  }

  void _clearTextEditing() {
    setState(() {
      _editingTextBlock = null;
      for (final model in _textBlocks.keys) {
        model.editing = false;
      }
    });
  }

  void _clearSelection() {
    _setSelection(const <Object>{});
  }

  void _setSelection(Set<Object> selection) {
    for (final model in _textBlocks.keys) {
      model.selected = selection.contains(model);
    }
    for (final model in _codeBlocks.keys) {
      model.selected = selection.contains(model);
    }
    for (final model in _strokes.keys) {
      model.selected = selection.contains(model);
    }
  }

  Set<Object> _selectedModels() => {
    ..._textBlocks.keys.where((model) => model.selected),
    ..._codeBlocks.keys.where((model) => model.selected),
    ..._strokes.keys.where((model) => model.selected),
  };

  GlobalKey _selectionKey(Object model) =>
      _selectionKeys.putIfAbsent(model, GlobalKey.new);

  void _moveSelectedChildren(ChangeNotifier dragged, Offset screenDelta) {
    if (!_documentLoaded ||
        _textPlacementEnabled ||
        _penEnabled ||
        _selectionModifierPressed.value ||
        screenDelta == Offset.zero) {
      return;
    }

    final selectedBeforeWidgetPointer = _selectionBeforeWidgetPointer;
    final draggedWasSelected = selectedBeforeWidgetPointer.contains(dragged);
    if (draggedWasSelected) _setSelection(selectedBeforeWidgetPointer);

    var draggedSelected = draggedWasSelected;
    if (dragged case final TextBlockModel model
        when _textBlocks.containsKey(model)) {
      draggedSelected = model.selected;
    } else if (dragged case final CodeBlockModel model
        when _codeBlocks.containsKey(model)) {
      draggedSelected = model.selected;
    } else if (dragged case final PenStrokeModel model
        when _strokes.containsKey(model)) {
      draggedSelected = model.selected;
    }

    if (!draggedSelected) _clearSelection();

    final gridDelta = screenDelta / _canvasController.scale;
    final ids = <CanvasChildId>[];
    final textModels = <TextBlockModel>[];
    final codeModels = <CodeBlockModel>[];
    for (final entry in _textBlocks.entries) {
      if (identical(entry.key, dragged) ||
          draggedSelected && entry.key.selected) {
        ids.add(entry.value);
        textModels.add(entry.key);
      }
    }
    for (final entry in _codeBlocks.entries) {
      if (identical(entry.key, dragged) ||
          draggedSelected && entry.key.selected) {
        ids.add(entry.value.id);
        codeModels.add(entry.key);
      }
    }
    for (final entry in _strokes.entries) {
      if (identical(entry.key, dragged) ||
          draggedSelected && entry.key.selected) {
        ids.add(entry.value);
      }
    }

    if (ids.isEmpty) return;
    _canvasController.moveChildrenBy(ids, gridDelta);
    for (final model in textModels) {
      model.node.position += gridDelta;
    }
    for (final model in codeModels) {
      final entry = _codeBlocks[model]!;
      _codeBlocks[model] = (
        id: entry.id,
        position: entry.position + gridDelta,
      );
    }
    if (textModels.isNotEmpty) _scheduleDocumentSave();
  }

  void _resizeTextBlock(
    TextBlockModel model,
    Size renderedSize,
    Offset screenDelta,
  ) {
    if (!_documentLoaded || _textPlacementEnabled || _penEnabled) return;
    if (!_textBlocks.containsKey(model)) return;
    model.resize(renderedSize, screenDelta / _canvasController.scale);
  }

  void _addTextBlock(Offset position) {
    if (!_documentLoaded) return;
    final node = TextNodeData(
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

    _mountTextBlock(model, requestFocus: true);
    _startTextEditing(model);
  }

  void _mountTextBlock(
    TextBlockModel model, {
    required bool requestFocus,
  }) {
    final node = model.node;
    final canvasId = _canvasController.addChild(
      node.position,
      _SelectionPointerRegion(
        key: _selectionKey(model),
        modifierPressed: _selectionModifierPressed,
        onPointerDown: (event) => _handleTextBlockPointerDown(model, event),
        child: TextBlock(
          model: model,
          attachmentStore: _attachmentStore,
          onEdit: () => _editTextBlock(model),
          onMove: (delta) => _moveSelectedChildren(model, delta),
          onResize: (size, delta) => _resizeTextBlock(model, size, delta),
        ),
      ),
      childSize: Size(node.width, node.height ?? textNodeMinimumHeight),
    );
    _textBlocks[model] = canvasId;
    model.addListener(_scheduleDocumentSave);
    if (requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => model.focusNode.requestFocus(),
      );
    }
  }

  void _addCodeBlock() {
    if (!_documentLoaded) return;
    _prepareInteractiveBlock();
    final size = _fittedBlockSize(const Size(600, 400), codeBlockMinimumSize);
    final model = CodeBlockModel(size);
    var position = _viewportCenter() - Offset(size.width / 2, size.height / 2);
    final placementOffset = const Offset(24, 24) / _canvasController.scale;
    while (_codeBlocks.values.any((block) => block.position == position)) {
      position += placementOffset;
    }

    final id = _canvasController.addChild(
      position,
      _SelectionPointerRegion(
        key: _selectionKey(model),
        modifierPressed: _selectionModifierPressed,
        onPointerDown: (event) => _handleCodeBlockPointerDown(model, event),
        child: CodeBlock(
          model: model,
          onMove: (delta) => _moveSelectedChildren(model, delta),
        ),
      ),
      childSize: size,
    );
    _codeBlocks[model] = (id: id, position: position);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => model.focusNode.requestFocus(),
    );
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
      _penEnabled = false;
      _textPlacementEnabled = false;
      _spaceHeld = false;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _addStroke(Sketch sketch) {
    final stroke = positionSketch(
      sketch,
      canvasOffset: _canvasController.offset,
      canvasScale: _canvasController.scale,
    );
    final model = PenStrokeModel(stroke.sketch, hitSlop: stroke.hitSlop);
    _strokes[model] = _canvasController.addChild(
      stroke.position,
      PenStroke(
        key: _selectionKey(model),
        model: model,
        size: stroke.size,
        onPointerDown: (event) => _handleStrokePointerDown(model, event),
        onMove: (delta) => _moveSelectedChildren(model, delta),
      ),
      childSize: stroke.size,
    );
  }

  void _handleStrokePointerDown(
    PenStrokeModel model,
    PointerDownEvent event,
  ) {
    if (event.buttons != kPrimaryButton ||
        !_documentLoaded ||
        _textPlacementEnabled ||
        _penEnabled ||
        !_strokes.containsKey(model)) {
      return;
    }
    _interactiveCanvasPointerIds.add(event.pointer);
    if (!_selectionModifierPressed.value) return;
    model.selected = !model.selected;
  }

  void _togglePen() {
    if (!_documentLoaded) return;
    if (!_penEnabled) _clearTextEditing();
    setState(() {
      _penEnabled = !_penEnabled;
      _textPlacementEnabled = false;
      _spaceHeld = false;
    });
    if (_penEnabled) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _showSettingsDialog() {
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: BTheme.of(context).colors.scrim,
        builder: (_) => SettingsDialog(
          canvasBackgroundKind: _canvasBackgroundKind,
          onCanvasBackgroundChanged: _setCanvasBackground,
        ),
      ),
    );
  }

  void _setCanvasBackground(CanvasBackgroundKind kind) {
    if (_canvasBackgroundKind == kind) return;
    _canvasBackgroundKind = kind;
    _canvasController.background = kind.build(BTheme.of(context).colors);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight) {
      _selectionModifierPressed.value =
          HardwareKeyboard.instance.isControlPressed;
    }
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final editingText =
        focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (!_penEnabled ||
        editingText ||
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
        for (final node in document.nodes) {
          _mountTextBlock(
            TextBlockModel(node),
            requestFocus: false,
          );
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
      nodes: _textBlocks.keys.map((model) => model.node).toList(),
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

  void _enqueueDocumentSave() {
    _saveTimer = null;
    if (!_documentLoaded || !_documentDirty) return;
    _documentDirty = false;
    final snapshot = _currentDocument().copy();
    _saveQueue = _saveQueue.then((_) => _saveDocument(snapshot));
  }

  Future<void> _saveDocument(CanvasDocument document) async {
    try {
      await _documentStore.save(document);
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
      _documentDirty = false;
      final snapshot = _currentDocument().copy();
      _saveQueue = _saveQueue.then((_) => _saveDocument(snapshot));
    }
    unawaited(_saveQueue);
    for (final block in _codeBlocks.keys) {
      block.dispose();
    }
    for (final block in _textBlocks.keys) {
      block
        ..removeListener(_scheduleDocumentSave)
        ..dispose();
    }
    for (final stroke in _strokes.keys) {
      stroke.dispose();
    }
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _selectionModifierPressed.dispose();
    _penTool.dispose();
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
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handleCanvasPointerDown,
              onPointerMove: _handleCanvasPointerMove,
              onPointerUp: _handleCanvasPointerUp,
              onPointerCancel: _handleCanvasPointerCancel,
              child: LazyCanvas(
                controller: _canvasController,
                mousePanButtons: kSecondaryMouseButton | kMiddleMouseButton,
              ),
            ),
          ),
          if (_penEnabled)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _spaceHeld,
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
            CompositedTransformFollower(
              link: anchor.layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.centerLeft,
              followerAnchor: Alignment.centerLeft,
              offset: TextBlockControls.followerOffset,
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
                        child: Semantics(
                          selected: _textPlacementEnabled,
                          child: TextButton(
                            onPressed: _toggleTextPlacement,
                            style: _toolbarButtonStyle(
                              colors,
                              geo,
                              selected: _textPlacementEnabled,
                              minimumSize: _toolbarSegmentMinimumSize,
                              borderRadius: geo.radiusMedium,
                            ),
                            child: const Text('Text'),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Add code block',
                        child: TextButton(
                          onPressed: _addCodeBlock,
                          style: _toolbarButtonStyle(
                            colors,
                            geo,
                            minimumSize: _toolbarSegmentMinimumSize,
                            borderRadius: geo.radiusMedium,
                          ),
                          child: const Text('Code'),
                        ),
                      ),
                      Tooltip(
                        message: 'Draw with pen',
                        child: Semantics(
                          selected: _penEnabled,
                          child: TextButton(
                            onPressed: _togglePen,
                            style: _toolbarButtonStyle(
                              colors,
                              geo,
                              selected: _penEnabled,
                              minimumSize: _toolbarSegmentMinimumSize,
                              borderRadius: geo.radiusMedium,
                            ),
                            child: const Text('Draw'),
                          ),
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
                padding: const EdgeInsets.all(12),
                child: ControlSurface(
                  key: const ValueKey('settings-button-surface'),
                  child: IconButton(
                    key: const ValueKey('settings-button'),
                    tooltip: 'Settings',
                    onPressed: _showSettingsDialog,
                    style: _toolbarIconButtonStyle(colors, geo),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionPointerRegion extends StatelessWidget {
  const _SelectionPointerRegion({
    required this.modifierPressed,
    required this.onPointerDown,
    required this.child,
    super.key,
  });

  final ValueListenable<bool> modifierPressed;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: onPointerDown,
      child: ListenableBuilder(
        listenable: modifierPressed,
        builder: (context, child) => AbsorbPointer(
          absorbing: modifierPressed.value,
          child: child,
        ),
        child: child,
      ),
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

const _toolbarSegmentMinimumSize = Size(88, 48);

ButtonStyle _toolbarButtonStyle(
  BColors colors,
  BGeo geo, {
  bool selected = false,
  Size? minimumSize,
  BorderRadius? borderRadius,
}) {
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (!selected) return colors.textSecondary;
      return colors.textPrimary;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) {
        return colors.surfacePressed;
      }
      if (states.contains(WidgetState.hovered)) return colors.surfaceHover;
      return selected ? colors.surfacePressed : Colors.transparent;
    }),
    side: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: colors.focusRing)
          : BorderSide.none,
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: borderRadius ?? geo.radiusSmall),
    ),
    minimumSize: minimumSize == null
        ? null
        : WidgetStatePropertyAll(minimumSize),
  );
}

ButtonStyle _toolbarIconButtonStyle(BColors colors, BGeo geo) {
  return _toolbarButtonStyle(
    colors,
    geo,
  ).copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.all(8)));
}
