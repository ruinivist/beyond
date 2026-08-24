import 'dart:async';
import 'dart:math' as math;

import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/tools/text/text_node.dart';
import 'package:beyond/foundation/control_surface.dart';
import 'package:beyond/foundation/pointer_scroll_boundary.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/utils/preset_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:google_fonts/google_fonts.dart';
// The renderer exposes its Markdown AST type through this callback.
// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;
import 'package:scroll_animator/scroll_animator.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

const int pastedImageMaximumBytes = 10 * 1024 * 1024;

const textFontOptions = <SelectOption<String>>[
  SelectOption(value: 'Source Serif 4', label: 'Source Serif 4'),
  SelectOption(value: 'Inter', label: 'Inter'),
  SelectOption(value: 'Roboto Mono', label: 'Roboto Mono'),
];

class TextBlockModel extends ChangeNotifier {
  TextBlockModel(this.node)
    : controller = TextEditingController(text: node.markdown) {
    controller.addListener(_syncMarkdown);
  }

  final TextNodeData node;
  final TextEditingController controller;
  final FocusNode focusNode = FocusNode();
  final scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );
  final layerLink = LayerLink();
  bool _editing = false;
  bool _selected = false;
  bool _resizing = false;

  bool get editing => _editing;

  set editing(bool value) {
    if (_editing == value) return;
    _editing = value;
    notifyListeners();
  }

  bool get selected => _selected;

  set selected(bool value) {
    if (_selected == value) return;
    _selected = value;
    notifyListeners();
  }

  bool get resizing => _resizing;

  set resizing(bool value) {
    if (_resizing == value) return;
    _resizing = value;
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

  Future<void> insertPastedImage(
    Uint8List bytes,
    String extension,
    AttachmentStore store,
  ) async {
    if (bytes.length > pastedImageMaximumBytes) {
      throw const FormatException('Image exceeds 10 MiB');
    }
    final path = 'attachments/${const Uuid().v4()}.$extension';
    await store.write(path, bytes);
    _insertText('![pasted image]($path)');
  }

  void insertPastedText(String text) => _insertText(text);

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

class TextBlock extends StatelessWidget {
  const TextBlock({
    required this.model,
    required this.attachmentStore,
    required this.onEdit,
    required this.onMove,
    required this.onResize,
    super.key,
  });

  final TextBlockModel model;
  final AttachmentStore attachmentStore;
  final VoidCallback onEdit;
  final ValueChanged<Offset> onMove;
  final void Function(Size renderedSize, Offset delta) onResize;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    return Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) {
          final body = model.editing
              ? _TextMarkdownEditor(
                  model: model,
                  attachmentStore: attachmentStore,
                )
              : _TextMarkdownPreview(
                  source: model.node.markdown,
                  style: model.style,
                  rotation: model.node.rotation,
                  scrollController: model.node.height == null
                      ? null
                      : model.scrollController,
                  onEdit: onEdit,
                  onMove: onMove,
                  attachmentStore: attachmentStore,
                );
          final configuredBody = ScrollConfiguration(
            behavior: const _TextBlockScrollBehavior(),
            child: body,
          );
          final visibleBody = model.node.height == null
              ? configuredBody
              : Scrollbar(
                  controller: model.scrollController,
                  thumbVisibility: true,
                  child: PointerScrollBoundary(child: configuredBody),
                );
          return Semantics(
            container: true,
            selected: model.selected,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: model.selected ? colors.accentSoft : Colors.transparent,
                border: model.selected
                    ? Border.all(color: colors.accent, width: 2)
                    : null,
                borderRadius: theme.geo.radiusSmall,
              ),
              child: CompositedTransformTarget(
                link: model.layerLink,
                child: SizedBox(
                  width: model.node.width,
                  height: model.node.height,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: textNodeMinimumHeight,
                    ),
                    child: Stack(
                      children: [
                        if (model.node.height != null)
                          Positioned.fill(child: visibleBody)
                        else
                          visibleBody,
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              reverseDuration: const Duration(
                                milliseconds: 180,
                              ),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,
                              transitionBuilder: _textResizeHandleTransition,
                              child: model.resizing
                                  ? SizedBox.expand(
                                      key: const ValueKey(
                                        'text-block-editing-border',
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: theme.geo.radiusSmall,
                                          border: Border.all(
                                            color: colors.border,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox(
                                      key: ValueKey(
                                        'text-block-editing-border-hidden',
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: SizedBox(
                            width: 32,
                            height: 20,
                            child: IgnorePointer(
                              ignoring: !model.editing,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                reverseDuration: const Duration(
                                  milliseconds: 180,
                                ),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeOutCubic,
                                transitionBuilder: _textResizeHandleTransition,
                                child: model.editing
                                    ? MouseRegion(
                                        cursor:
                                            SystemMouseCursors.resizeDownRight,
                                        child: TextFieldTapRegion(
                                          child: ControlSurface(
                                            child: Semantics(
                                              button: true,
                                              label: 'Resize text block',
                                              child: RawGestureDetector(
                                                key: const ValueKey(
                                                  'text-block-resize-handle',
                                                ),
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                gestures: {
                                                  ImmediateMultiDragGestureRecognizer:
                                                      GestureRecognizerFactoryWithHandlers<
                                                        ImmediateMultiDragGestureRecognizer
                                                      >(
                                                        ImmediateMultiDragGestureRecognizer
                                                            .new,
                                                        (recognizer) {
                                                          recognizer
                                                              .onStart = (_) {
                                                            model.resizing =
                                                                true;
                                                            return _TextBlockResizeDrag(
                                                              (
                                                                delta,
                                                              ) => onResize(
                                                                context.size!,
                                                                delta,
                                                              ),
                                                              () =>
                                                                  model.resizing =
                                                                      false,
                                                            );
                                                          };
                                                        },
                                                      ),
                                                },
                                                child: Center(
                                                  child: Icon(
                                                    Icons.open_in_full,
                                                    size: 16,
                                                    color: colors.textMuted,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : const SizedBox(
                                        key: ValueKey(
                                          'text-block-resize-handle-hidden',
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TextBlockScrollBehavior extends MaterialScrollBehavior {
  const _TextBlockScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

Widget _textResizeHandleTransition(
  Widget child,
  Animation<double> animation,
) {
  return FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
      alignment: Alignment.bottomRight,
      child: child,
    ),
  );
}

class _TextMarkdownEditor extends StatefulWidget {
  const _TextMarkdownEditor({
    required this.model,
    required this.attachmentStore,
  });

  final TextBlockModel model;
  final AttachmentStore attachmentStore;

  @override
  State<_TextMarkdownEditor> createState() => _TextMarkdownEditorState();
}

class _TextMarkdownEditorState extends State<_TextMarkdownEditor> {
  ClipboardEvents? get _events => ClipboardEvents.instance;

  @override
  void initState() {
    super.initState();
    _events?.registerPasteEventListener(_onWebPaste);
  }

  @override
  void dispose() {
    _events?.unregisterPasteEventListener(_onWebPaste);
    super.dispose();
  }

  void _onWebPaste(ClipboardReadEvent event) {
    if (!widget.model.focusNode.hasFocus) return;
    unawaited(_paste(event.getClipboardReader()));
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (_events != null ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyV ||
        (!HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isMetaPressed)) {
      return KeyEventResult.ignored;
    }
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return KeyEventResult.ignored;
    unawaited(_paste(clipboard.read()));
    return KeyEventResult.handled;
  }

  Future<void> _paste(Future<ClipboardReader> readerFuture) async {
    try {
      final reader = await readerFuture;
      final formats = reader.getFormats(_pastedImageFormats.keys.toList());
      if (formats.isNotEmpty) {
        final format = formats.first as FileFormat;
        final bytes = await _readClipboardFile(reader, format);
        if (bytes == null) throw StateError('Could not read clipboard image');
        await widget.model.insertPastedImage(
          bytes,
          _pastedImageFormats[format]!,
          widget.attachmentStore,
        );
      } else if (reader.canProvide(Formats.plainText)) {
        final text = await reader.readValue(Formats.plainText);
        if (text != null) widget.model.insertPastedText(text);
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not paste image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final code = theme.typo.code;
    return Focus(
      onKeyEvent: _onKeyEvent,
      child: TextField(
        key: const ValueKey('text-markdown-editor'),
        controller: widget.model.controller,
        focusNode: widget.model.focusNode,
        scrollController: widget.model.scrollController,
        expands: widget.model.node.height != null,
        maxLines: null,
        cursorColor: colors.accent,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
          hintText: 'Type something',
          hintStyle: code.copyWith(color: colors.textMuted),
        ),
        style: code.copyWith(color: colors.textPrimary),
      ),
    );
  }
}

const Map<FileFormat, String> _pastedImageFormats = <FileFormat, String>{
  Formats.png: 'png',
  Formats.jpeg: 'jpg',
  Formats.gif: 'gif',
  Formats.webp: 'webp',
};

Future<Uint8List?> _readClipboardFile(
  ClipboardReader reader,
  FileFormat format,
) {
  final result = Completer<Uint8List?>();
  final progress = reader.getFile(
    format,
    (file) async {
      try {
        if ((file.fileSize ?? 0) > pastedImageMaximumBytes) {
          throw const FormatException('Image exceeds 10 MiB');
        }
        final bytes = await file.readAll();
        if (!result.isCompleted) result.complete(bytes);
      } on Object catch (error, stackTrace) {
        if (!result.isCompleted) result.completeError(error, stackTrace);
      }
    },
    onError: (error) {
      if (!result.isCompleted) result.completeError(error);
    },
  );
  if (progress == null) result.complete(null);
  return result.future;
}

class _TextMarkdownPreview extends StatelessWidget {
  const _TextMarkdownPreview({
    required this.source,
    required this.style,
    required this.rotation,
    required this.scrollController,
    required this.onEdit,
    required this.onMove,
    required this.attachmentStore,
  });

  final String source;
  final TextNodeStyle style;
  final double rotation;
  final ScrollController? scrollController;
  final VoidCallback onEdit;
  final ValueChanged<Offset> onMove;
  final AttachmentStore attachmentStore;

  @override
  Widget build(BuildContext context) {
    final content = source.isEmpty
        ? _EmptyTextMarkdownPreview(
            key: const ValueKey('text-markdown-preview'),
            style: style,
          )
        : MarkdownBody(
            key: const ValueKey('text-markdown-preview'),
            data: source,
            blockSyntaxes: [LatexBlockSyntax()],
            inlineSyntaxes: [
              _TextImageSyntax(),
              LatexInlineSyntax(),
            ],
            builders: {
              'latex': LatexElementBuilder(
                textStyle: _fontStyle(style),
              ),
            },
            styleSheet: _styleSheet(context, style),
            imageBuilder: (uri, title, alt) =>
                _buildImage(uri, alt, attachmentStore),
            onTapLink: (_, href, _) => _openLink(context, href),
          );
    return GestureDetector(
      key: const ValueKey('text-markdown-preview-surface'),
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onTap: onEdit,
      onPanUpdate: (details) =>
          onMove(_localToScreenDelta(details.delta, rotation)),
      child: scrollController == null
          ? content
          : SingleChildScrollView(
              controller: scrollController,
              child: content,
            ),
    );
  }
}

Offset _localToScreenDelta(Offset delta, double rotation) {
  final cosine = math.cos(rotation);
  final sine = math.sin(rotation);
  return Offset(
    delta.dx * cosine - delta.dy * sine,
    delta.dx * sine + delta.dy * cosine,
  );
}

class _EmptyTextMarkdownPreview extends StatelessWidget {
  const _EmptyTextMarkdownPreview({required this.style, super.key});

  final TextNodeStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return SizedBox(
      height: 52,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Click to edit',
            style: _fontStyle(
              style,
            ).copyWith(color: theme.colors.textMuted),
          ),
        ),
      ),
    );
  }
}

MarkdownStyleSheet _styleSheet(
  BuildContext context,
  TextNodeStyle style,
) {
  final theme = BTheme.of(context);
  final colors = theme.colors;
  final base = _fontStyle(style).copyWith(height: 1.5);
  double scaled(double ratio) => style.fontSize * ratio;

  final code = theme.typo.code.copyWith(
    color: colors.textPrimary,
    fontSize: scaled(0.85),
    backgroundColor: colors.surfaceSubtle,
  );
  final table = base.copyWith(fontSize: scaled(0.875), height: 1.45);

  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    a: base.copyWith(color: colors.accent),
    p: base,
    code: code,
    h1: base.copyWith(
      fontSize: scaled(1.50),
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    h2: base.copyWith(
      fontSize: scaled(1.375),
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    h3: base.copyWith(
      fontSize: scaled(1.25),
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    h4: base.copyWith(
      fontSize: scaled(1.125),
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    h5: base.copyWith(
      fontSize: scaled(1.0625),
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    h6: base.copyWith(fontWeight: FontWeight.w600, height: 1.4),
    em: base.copyWith(fontStyle: FontStyle.italic),
    strong: base.copyWith(fontWeight: FontWeight.w600),
    del: base.copyWith(decoration: TextDecoration.lineThrough),
    blockquote: base,
    img: base,
    checkbox: base.copyWith(color: colors.accent),
    listBullet: base,
    tableHead: table.copyWith(fontWeight: FontWeight.w600),
    tableBody: table,
    codeblockDecoration: BoxDecoration(color: colors.surfaceSubtle),
  );
}

TextStyle _fontStyle(TextNodeStyle style) {
  final base = TextStyle(
    fontSize: style.fontSize,
    color: colorFromHex(style.color),
  );

  return switch (style.fontFamily) {
    'Source Serif 4' => GoogleFonts.sourceSerif4(textStyle: base),
    'Inter' => GoogleFonts.inter(textStyle: base),
    'Roboto Mono' => GoogleFonts.robotoMono(textStyle: base),
    _ => throw StateError('Validated font family became invalid'),
  };
}

String colorToHex(Color color) {
  final value = color.toARGB32() & 0x00ffffff;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color colorFromHex(String value) {
  return Color(int.parse('FF${value.substring(1)}', radix: 16));
}

class TextBlockControls extends StatelessWidget {
  const TextBlockControls({
    required this.model,
    required this.onMove,
    required this.onRotate,
    required this.rotationCenter,
    super.key,
  });

  final TextBlockModel model;
  final ValueChanged<Offset> onMove;
  final ValueChanged<double> onRotate;
  final ValueGetter<Offset> rotationCenter;

  static const size = Size(500, 168);
  static const followerOffset = Offset(-132, 0);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 30,
            child: TextSettings(model: model),
          ),
          Positioned(
            top: 63,
            left: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: TextFieldTapRegion(
                child: ControlSurface(
                  child: Semantics(
                    button: true,
                    label: 'Move text block',
                    child: RawGestureDetector(
                      key: const ValueKey('text-block-handle'),
                      behavior: HitTestBehavior.opaque,
                      gestures: {
                        ImmediateMultiDragGestureRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                              ImmediateMultiDragGestureRecognizer
                            >(
                              ImmediateMultiDragGestureRecognizer.new,
                              (recognizer) {
                                recognizer.onStart = (_) =>
                                    _TextBlockDrag(onMove);
                              },
                            ),
                      },
                      child: const SizedBox.square(
                        dimension: 48,
                        child: Icon(Icons.drag_indicator, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 127,
            left: 30,
            child: Tooltip(
              message: 'Rotate text',
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: TextFieldTapRegion(
                  child: ControlSurface(
                    child: Semantics(
                      button: true,
                      label: 'Rotate text block',
                      child: RawGestureDetector(
                        key: const ValueKey('text-block-rotate-control'),
                        behavior: HitTestBehavior.opaque,
                        gestures: {
                          ImmediateMultiDragGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                ImmediateMultiDragGestureRecognizer
                              >(
                                ImmediateMultiDragGestureRecognizer.new,
                                (recognizer) {
                                  recognizer.onStart = (position) =>
                                      _TextBlockRotateDrag(
                                        startPosition: position,
                                        center: rotationCenter(),
                                        rotation: model.node.rotation,
                                        onRotate: onRotate,
                                      );
                                },
                              ),
                        },
                        child: const SizedBox.square(
                          dimension: 32,
                          child: Icon(Icons.rotate_right, size: 24),
                        ),
                      ),
                    ),
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

class TextSettings extends StatefulWidget {
  const TextSettings({required this.model, super.key});

  final TextBlockModel model;

  @override
  State<TextSettings> createState() => _TextSettingsState();
}

class _TextSettingsState extends State<TextSettings> {
  final _colorMenu = MenuController();
  var _open = false;

  @override
  void didUpdateWidget(covariant TextSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) _open = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    return ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) {
        final style = widget.model.style;
        final selectedColor = colorFromHex(style.color);
        return SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Tooltip(
                message: _open ? 'Close text settings' : 'Open text settings',
                child: ControlSurface(
                  selected: _open,
                  child: IconButton(
                    key: const ValueKey('text-settings-button'),
                    onPressed: () => setState(() => _open = !_open),
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(32),
                      shape: RoundedRectangleBorder(
                        borderRadius: theme.geo.radiusLarge,
                      ),
                    ),
                    icon: Transform.translate(
                      offset: _open ? const Offset(0, 1) : Offset.zero,
                      child: const Icon(Icons.tune, size: 22),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 48),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        axis: Axis.horizontal,
                        alignment: Alignment.centerLeft,
                        sizeFactor: animation,
                        child: child,
                      ),
                    ),
                    child: _open
                        ? Padding(
                            key: const ValueKey('text-settings-open'),
                            padding: const EdgeInsets.only(left: 8),
                            child: Material(
                              key: const ValueKey('text-settings-panel'),
                              color: colors.surfaceRaised,
                              elevation: theme.geo.elevationLow,
                              shadowColor: colors.shadow,
                              shape: RoundedRectangleBorder(
                                borderRadius: theme.geo.radiusLarge,
                                side: BorderSide(color: colors.borderSubtle),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 230,
                                      child: Select<String>(
                                        key: const ValueKey('text-font-select'),
                                        value: style.fontFamily,
                                        options: textFontOptions,
                                        onChanged: (fontFamily) {
                                          widget.model.style = style.copyWith(
                                            fontFamily: fontFamily,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    MenuAnchor(
                                      controller: _colorMenu,
                                      style: MenuStyle(
                                        backgroundColor: WidgetStatePropertyAll(
                                          colors.surfaceRaised,
                                        ),
                                        elevation: WidgetStatePropertyAll(
                                          theme.geo.elevationMedium,
                                        ),
                                        padding: const WidgetStatePropertyAll(
                                          EdgeInsets.all(8),
                                        ),
                                        shape: WidgetStatePropertyAll(
                                          RoundedRectangleBorder(
                                            borderRadius: theme.geo.radiusLarge,
                                            side: BorderSide(
                                              color: colors.borderSubtle,
                                            ),
                                          ),
                                        ),
                                      ),
                                      menuChildren: [
                                        SizedBox(
                                          width: 176,
                                          child: Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: [
                                              for (final swatch in presetColors)
                                                Tooltip(
                                                  message: swatch.label,
                                                  child: Semantics(
                                                    button: true,
                                                    selected:
                                                        selectedColor ==
                                                        swatch.color,
                                                    label:
                                                        'Use ${swatch.label}',
                                                    child: IconButton(
                                                      key: ValueKey(
                                                        'text-color-${swatch.label}',
                                                      ),
                                                      onPressed: () {
                                                        widget.model.style =
                                                            style.copyWith(
                                                              color: colorToHex(
                                                                swatch.color,
                                                              ),
                                                            );
                                                        _colorMenu.close();
                                                      },
                                                      style: IconButton.styleFrom(
                                                        minimumSize:
                                                            const Size.square(
                                                              40,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        shape:
                                                            const CircleBorder(),
                                                        side: BorderSide(
                                                          color:
                                                              selectedColor ==
                                                                  swatch.color
                                                              ? colors.focusRing
                                                              : Colors
                                                                    .transparent,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      icon: DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          color: swatch.color,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: colors
                                                                .borderSubtle,
                                                          ),
                                                        ),
                                                        child:
                                                            const SizedBox.square(
                                                              dimension: 20,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      builder: (context, controller, _) =>
                                          IconButton(
                                            key: const ValueKey(
                                              'text-settings-color',
                                            ),
                                            tooltip: 'Choose text color',
                                            onPressed: controller.isOpen
                                                ? controller.close
                                                : controller.open,
                                            style:
                                                IconButton.styleFrom(
                                                  minimumSize:
                                                      const Size.square(40),
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  shape: const CircleBorder(),
                                                ).copyWith(
                                                  overlayColor:
                                                      WidgetStateProperty.resolveWith(
                                                        (states) =>
                                                            states.contains(
                                                              WidgetState
                                                                  .focused,
                                                            )
                                                            ? colors.focusRing
                                                                  .withValues(
                                                                    alpha: 0.18,
                                                                  )
                                                            : Colors
                                                                  .transparent,
                                                      ),
                                                ),
                                            icon: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: selectedColor,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: colors.borderSubtle,
                                                ),
                                              ),
                                              child: const SizedBox.square(
                                                dimension: 24,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('text-settings-closed'),
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _sameStyle(TextNodeStyle first, TextNodeStyle second) {
  return first.fontFamily == second.fontFamily &&
      first.fontSize == second.fontSize &&
      first.color == second.color;
}

Widget _buildImage(Uri uri, String? alt, AttachmentStore attachmentStore) {
  final path = uri.toString();
  if (attachmentPathPattern.hasMatch(path)) {
    return FutureBuilder<Uint8List>(
      future: attachmentStore.read(path),
      builder: (_, snapshot) => switch (snapshot) {
        AsyncSnapshot(hasData: true, data: final bytes?) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Image.memory(
            bytes,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorBuilder: (_, _, _) => _TextImageError(alt: alt),
          ),
        ),
        AsyncSnapshot(hasError: true) => _TextImageError(alt: alt),
        _ => const SizedBox.shrink(),
      },
    );
  }
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.host.contains('%')) {
    return _TextImageError(alt: alt);
  }
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Image.network(
      uri.toString(),
      width: double.infinity,
      fit: BoxFit.fitWidth,
      errorBuilder: (_, _, _) => _TextImageError(alt: alt),
    ),
  );
}

class _TextImageSyntax extends md.InlineSyntax {
  _TextImageSyntax()
    : super(
        r"""!\[([^\]]*)\]\((?:<([^>]*)>|([^\s)]+))(?:\s+(?:"([^"]*)"|'([^']*)'|\(([^)]*)\)))?\)""",
        startCharacter: 33,
      );

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    // Leave valid images to the renderer so enclosing link recognizers survive.
    startMatchPos ??= parser.pos;
    final match = pattern.matchAsPrefix(parser.source, startMatchPos);
    if (match == null) return false;
    final source = match[2] ?? match[3]!;
    if (Uri.tryParse(source) != null) return false;
    return super.tryMatch(parser, startMatchPos);
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final image = md.Element.empty('img')
      ..attributes['src'] = 'http://invalid-image'
      ..attributes['alt'] = match[1]!;
    final title = match[4] ?? match[5] ?? match[6];
    if (title != null) image.attributes['title'] = title;
    parser.addNode(image);
    return true;
  }
}

class _TextImageError extends StatelessWidget {
  const _TextImageError({this.alt});

  final String? alt;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: alt,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}

Future<void> _openLink(BuildContext context, String? href) async {
  final uri = href == null ? null : Uri.tryParse(href);
  final supported =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
  if (supported) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Exception {
      // The same feedback covers unavailable and failed platform launchers.
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Could not open link')));
}

class _TextBlockDrag extends Drag {
  _TextBlockDrag(this.onMove);

  final ValueChanged<Offset> onMove;

  @override
  void update(DragUpdateDetails details) => onMove(details.delta);
}

class _TextBlockResizeDrag extends Drag {
  _TextBlockResizeDrag(this.onResize, this.onEnd);

  final ValueChanged<Offset> onResize;
  final VoidCallback onEnd;

  @override
  void update(DragUpdateDetails details) => onResize(details.delta);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onEnd();
}

class _TextBlockRotateDrag extends Drag {
  _TextBlockRotateDrag({
    required Offset startPosition,
    required this.center,
    required this._rotation,
    required this.onRotate,
  }) : _lastPointerAngle = _pointerAngle(startPosition, center);

  final Offset center;
  final ValueChanged<double> onRotate;
  double _lastPointerAngle;
  double _rotation;

  @override
  void update(DragUpdateDetails details) {
    final pointerAngle = _pointerAngle(details.globalPosition, center);
    var delta = pointerAngle - _lastPointerAngle;
    if (delta > math.pi) delta -= math.pi * 2;
    if (delta < -math.pi) delta += math.pi * 2;
    _rotation += delta;
    _lastPointerAngle = pointerAngle;
    onRotate(_rotation);
  }
}

double _pointerAngle(Offset pointer, Offset center) =>
    math.atan2(pointer.dy - center.dy, pointer.dx - center.dx);
