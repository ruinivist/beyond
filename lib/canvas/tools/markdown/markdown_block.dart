import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_theme.dart';
import '../../smooth_scroll_controller.dart';

const markdownBlockMinimumSize = Size(320, 240);

class MarkdownBlockModel extends ChangeNotifier {
  MarkdownBlockModel(Size size) : _size = _clampSize(size);

  final controller = TextEditingController();
  final focusNode = FocusNode();
  final scrollController = SmoothScrollController();
  Size _size;
  bool _selected = false;
  bool _previewing = false;

  Size get size => _size;

  set size(Size value) {
    final nextSize = _clampSize(value);
    if (_size == nextSize) return;
    _size = nextSize;
    notifyListeners();
  }

  bool get selected => _selected;

  set selected(bool value) {
    if (_selected == value) return;
    _selected = value;
    notifyListeners();
  }

  bool get previewing => _previewing;

  set previewing(bool value) {
    if (_previewing == value) return;
    _previewing = value;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }
}

Size _clampSize(Size size) => Size(
  math.max(markdownBlockMinimumSize.width, size.width),
  math.max(markdownBlockMinimumSize.height, size.height),
);

class MarkdownBlock extends StatelessWidget {
  const MarkdownBlock({
    required this.model,
    required this.onSelect,
    required this.onMove,
    super.key,
  });

  final MarkdownBlockModel model;
  final ValueChanged<PointerDownEvent> onSelect;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final block = appTheme.components.block;
    final mono = appTheme.typography.mono;
    return Listener(
      onPointerDown: onSelect,
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) => SizedBox.fromSize(
          size: model.size,
          child: Material(
            key: const ValueKey('markdown-block-surface'),
            color: block.background,
            elevation: model.selected
                ? block.selectedElevation
                : block.elevation,
            shadowColor: block.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(block.radius),
              side: model.selected
                  ? BorderSide(color: block.selectedBorder, width: 2)
                  : BorderSide(color: block.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  children: [
                    _MarkdownBlockHeader(model: model, onMove: onMove),
                    Divider(height: 1, color: block.divider),
                    Expanded(
                      child: model.previewing
                          ? _MarkdownPreview(
                              source: model.controller.text,
                              controller: model.scrollController,
                            )
                          : TextField(
                              key: const ValueKey('markdown-editor'),
                              controller: model.controller,
                              focusNode: model.focusNode,
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              cursorColor: block.selectedBorder,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                                hintText: 'Write Markdown…',
                                hintStyle: mono.copyWith(
                                  color: block.mutedForeground,
                                ),
                              ),
                              style: mono.copyWith(color: block.foreground),
                            ),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _MarkdownBlockResizeHandle(model: model),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.source, required this.controller});

  final String source;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final block = appTheme.components.block;
    final editorial = appTheme.typography.editorial;
    final mono = appTheme.typography.mono;
    final prose = editorial.bodyMedium!.copyWith(color: block.foreground);
    return Markdown(
      key: const ValueKey('markdown-preview'),
      controller: controller,
      data: source,
      selectable: true,
      blockSyntaxes: [LatexBlockSyntax()],
      inlineSyntaxes: [LatexInlineSyntax()],
      builders: {'latex': LatexElementBuilder()},
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        a: prose.copyWith(color: block.selectedBorder),
        p: prose,
        code: mono.copyWith(
          color: block.foreground,
          fontSize: 13,
          backgroundColor: appTheme.colors.surfaceSubtle,
        ),
        h1: editorial.headlineLarge!.copyWith(color: block.foreground),
        h2: editorial.headlineMedium!.copyWith(color: block.foreground),
        h3: editorial.headlineSmall!.copyWith(color: block.foreground),
        h4: editorial.titleLarge!.copyWith(color: block.foreground),
        h5: editorial.titleMedium!.copyWith(color: block.foreground),
        h6: editorial.titleSmall!.copyWith(color: block.foreground),
        em: prose.copyWith(fontStyle: FontStyle.italic),
        strong: prose.copyWith(fontWeight: FontWeight.w600),
        del: prose.copyWith(decoration: TextDecoration.lineThrough),
        blockquote: prose,
        img: prose,
        checkbox: prose.copyWith(color: block.selectedBorder),
        listBullet: prose,
        tableHead: editorial.bodySmall!.copyWith(
          color: block.foreground,
          fontWeight: FontWeight.w600,
        ),
        tableBody: editorial.bodySmall!.copyWith(color: block.foreground),
      ),
      imageBuilder: (uri, title, alt) {
        if (uri.scheme != 'https' || uri.host.isEmpty) {
          return _ImageError(alt: alt);
        }
        return Image.network(
          uri.toString(),
          errorBuilder: (_, _, _) => _ImageError(alt: alt),
        );
      },
      onTapLink: (_, href, _) => _openLink(context, href),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError({this.alt});

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

class _MarkdownBlockHeader extends StatelessWidget {
  const _MarkdownBlockHeader({required this.model, required this.onMove});

  final MarkdownBlockModel model;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    final block = context.appTheme.components.block;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: RawGestureDetector(
                key: const ValueKey('markdown-block-header'),
                behavior: HitTestBehavior.opaque,
                gestures: {
                  ImmediateMultiDragGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        ImmediateMultiDragGestureRecognizer
                      >(ImmediateMultiDragGestureRecognizer.new, (recognizer) {
                        recognizer.onStart = (_) => _MarkdownBlockDrag(onMove);
                      }),
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: block.secondaryForeground,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              key: const ValueKey('markdown-mode-toggle'),
              mainAxisSize: MainAxisSize.min,
              children: [
                _MarkdownModeTab(
                  label: 'Edit',
                  selected: !model.previewing,
                  onPressed: () => _setPreviewing(false),
                ),
                _MarkdownModeTab(
                  label: 'Preview',
                  selected: model.previewing,
                  onPressed: () => _setPreviewing(true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setPreviewing(bool previewing) {
    model.previewing = previewing;
    if (!previewing) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => model.focusNode.requestFocus(),
      );
    }
  }
}

class _MarkdownModeTab extends StatelessWidget {
  const _MarkdownModeTab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final block = context.appTheme.components.block;
    return Semantics(
      selected: selected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onPressed,
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(
                selected ? block.selectedBorder : block.secondaryForeground,
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return block.pressedBackground;
                }
                if (states.contains(WidgetState.hovered)) {
                  return block.hoverBackground;
                }
                return Colors.transparent;
              }),
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? BorderSide(color: block.focus)
                    : BorderSide.none,
              ),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
            ),
            child: Text(label),
          ),
          SizedBox(
            height: 2,
            width: 56,
            child: ColoredBox(
              color: selected ? block.selectedBorder : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownBlockResizeHandle extends StatelessWidget {
  const _MarkdownBlockResizeHandle({required this.model});

  final MarkdownBlockModel model;

  @override
  Widget build(BuildContext context) {
    final color = context.appTheme.components.block.mutedForeground;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: Semantics(
        button: true,
        label: 'Resize markdown block',
        child: GestureDetector(
          key: const ValueKey('markdown-block-resize-handle'),
          behavior: HitTestBehavior.opaque,
          onScaleUpdate: (details) {
            model.size = Size(
              model.size.width + details.focalPointDelta.dx,
              model.size.height + details.focalPointDelta.dy,
            );
          },
          child: SizedBox(
            width: 28,
            height: 28,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.open_in_full, size: 16, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkdownBlockDrag extends Drag {
  _MarkdownBlockDrag(this.onMove);

  final ValueChanged<Offset> onMove;

  @override
  void update(DragUpdateDetails details) => onMove(details.delta);
}
