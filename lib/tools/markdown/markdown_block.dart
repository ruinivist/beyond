import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:url_launcher/url_launcher.dart';

const markdownBlockMinimumSize = Size(320, 240);

class MarkdownBlockModel extends ChangeNotifier {
  MarkdownBlockModel(Size size) : _size = _clampSize(size);

  final controller = TextEditingController();
  final focusNode = FocusNode();
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
    return Listener(
      onPointerDown: onSelect,
      child: ListenableBuilder(
        listenable: model,
        builder: (context, _) => SizedBox.fromSize(
          size: model.size,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: model.selected ? 12 : 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: model.selected
                  ? BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  children: [
                    _MarkdownBlockHeader(model: model, onMove: onMove),
                    const Divider(height: 1),
                    Expanded(
                      child: model.previewing
                          ? _MarkdownPreview(source: model.controller.text)
                          : TextField(
                              key: const ValueKey('markdown-editor'),
                              controller: model.controller,
                              focusNode: model.focusNode,
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(16),
                                hintText: 'Write Markdown…',
                              ),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                height: 1.4,
                              ),
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
  const _MarkdownPreview({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    return Markdown(
      key: const ValueKey('markdown-preview'),
      data: source,
      selectable: true,
      blockSyntaxes: [LatexBlockSyntax()],
      inlineSyntaxes: [LatexInlineSyntax()],
      builders: {'latex': LatexElementBuilder()},
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(Icons.description_outlined, size: 18),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<bool>(
              key: const ValueKey('markdown-mode-toggle'),
              segments: const [
                ButtonSegment(value: false, label: Text('Edit')),
                ButtonSegment(value: true, label: Text('Preview')),
              ],
              selected: {model.previewing},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelectionChanged: (selection) {
                model.previewing = selection.single;
                if (!model.previewing) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => model.focusNode.requestFocus(),
                  );
                }
              },
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
          child: const SizedBox(
            width: 28,
            height: 28,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.open_in_full,
                  size: 16,
                  color: Colors.black54,
                ),
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
