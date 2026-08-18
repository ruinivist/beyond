import 'dart:math' as math;

import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:scroll_animator/scroll_animator.dart';
import 'package:url_launcher/url_launcher.dart';

const markdownBlockMinimumSize = Size(320, 240);

class MarkdownBlockModel extends ChangeNotifier {
  MarkdownBlockModel(Size size) : _size = _clampSize(size);

  final controller = TextEditingController();
  final focusNode = FocusNode();
  final scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );
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
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final code = theme.typo.code;
    final geo = theme.geo;
    return Listener(
      onPointerDown: onSelect,
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) => SizedBox.fromSize(
          size: model.size,
          child: Material(
            key: const ValueKey('markdown-block-surface'),
            color: colors.surface,
            elevation: model.selected ? geo.elevationHigh : geo.elevationMedium,
            shadowColor: colors.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: geo.radiusLarge,
              side: model.selected
                  ? BorderSide(color: colors.accent, width: 2)
                  : BorderSide(color: colors.borderSubtle),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  children: [
                    _MarkdownBlockHeader(model: model, onMove: onMove),
                    Divider(height: 1, color: colors.borderSubtle),
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
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              cursorColor: colors.accent,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                                hintText: 'Write Markdown…',
                                hintStyle: code.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                              style: code.copyWith(color: colors.textPrimary),
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
    final colors = BTheme.of(context).colors;
    final typo = BTheme.of(context).typo;
    final sourceSerif = TextStyle(
      fontFamily: typo.heading.fontFamily,
      fontFamilyFallback: typo.heading.fontFamilyFallback,
    );
    final prose = sourceSerif.copyWith(
      color: colors.textPrimary,
      fontSize: 16,
      height: 1.5,
    );
    return Markdown(
      key: const ValueKey('markdown-preview'),
      controller: controller,
      data: source,
      selectable: true,
      blockSyntaxes: [LatexBlockSyntax()],
      inlineSyntaxes: [LatexInlineSyntax()],
      builders: {'latex': LatexElementBuilder()},
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        a: prose.copyWith(color: colors.accent),
        p: prose,
        code: typo.code.copyWith(
          color: colors.textPrimary,
          fontSize: 13,
          backgroundColor: colors.surfaceSubtle,
        ),
        h1: sourceSerif.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: colors.textPrimary,
        ),
        h2: sourceSerif.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.25,
          color: colors.textPrimary,
        ),
        h3: sourceSerif.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: colors.textPrimary,
        ),
        h4: sourceSerif.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: colors.textPrimary,
        ),
        h5: sourceSerif.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: colors.textPrimary,
        ),
        h6: sourceSerif.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: colors.textPrimary,
        ),
        em: prose.copyWith(fontStyle: FontStyle.italic),
        strong: prose.copyWith(fontWeight: FontWeight.w600),
        del: prose.copyWith(decoration: TextDecoration.lineThrough),
        blockquote: prose,
        img: prose,
        checkbox: prose.copyWith(color: colors.accent),
        listBullet: prose,
        tableHead: sourceSerif.copyWith(
          fontSize: 14,
          height: 1.45,
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        tableBody: sourceSerif.copyWith(
          fontSize: 14,
          height: 1.45,
          color: colors.textPrimary,
        ),
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
    final colors = BTheme.of(context).colors;
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
                      color: colors.textSecondary,
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
    final colors = BTheme.of(context).colors;
    return Semantics(
      selected: selected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onPressed,
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(
                selected ? colors.accent : colors.textSecondary,
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return colors.surfacePressed;
                }
                if (states.contains(WidgetState.hovered)) {
                  return colors.surfaceHover;
                }
                return Colors.transparent;
              }),
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? BorderSide(color: colors.focusRing)
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
              color: selected ? colors.accent : Colors.transparent,
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
    final color = BTheme.of(context).colors.textMuted;
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
