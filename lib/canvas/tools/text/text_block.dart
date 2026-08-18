import 'package:beyond/canvas/tools/text/text_node.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
// The renderer exposes its Markdown AST type through this callback.
// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

class TextBlockModel extends ChangeNotifier {
  TextBlockModel(this.node)
    : controller = TextEditingController(text: node.markdown) {
    controller.addListener(_syncMarkdown);
    focusNode.addListener(notifyListeners);
  }

  final TextNodeData node;
  final TextEditingController controller;
  final FocusNode focusNode = FocusNode();

  void _syncMarkdown() {
    if (node.markdown == controller.text) return;
    node.markdown = controller.text;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_syncMarkdown);
    focusNode.removeListener(notifyListeners);
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }
}

class TextBlock extends StatelessWidget {
  const TextBlock({
    required this.model,
    required this.onSelect,
    required this.onMove,
    super.key,
  });

  final TextBlockModel model;
  final ValueChanged<PointerDownEvent> onSelect;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    final colors = BTheme.of(context).colors;
    return Listener(
      onPointerDown: onSelect,
      child: Material(
        type: MaterialType.transparency,
        child: ListenableBuilder(
          listenable: model,
          builder: (context, _) {
            final focused = model.focusNode.hasFocus;
            return SizedBox(
              width: model.node.width,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Stack(
                  children: [
                    if (focused)
                      _TextMarkdownEditor(model: model)
                    else
                      Focus(
                        focusNode: model.focusNode,
                        child: _TextMarkdownPreview(model: model),
                      ),
                    if (focused)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 28,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: TextFieldTapRegion(
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
                                        (
                                          recognizer,
                                        ) {
                                          recognizer.onStart = (_) =>
                                              _TextBlockDrag(onMove);
                                        },
                                      ),
                                },
                                child: Center(
                                  child: Icon(
                                    Icons.drag_indicator,
                                    size: 18,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TextMarkdownEditor extends StatelessWidget {
  const _TextMarkdownEditor({required this.model});

  final TextBlockModel model;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final code = theme.typo.code;
    return TextField(
      key: const ValueKey('text-markdown-editor'),
      controller: model.controller,
      focusNode: model.focusNode,
      autofocus: true,
      maxLines: null,
      cursorColor: colors.accent,
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 28, 12),
        hintText: 'Type something',
        hintStyle: code.copyWith(color: colors.textMuted),
      ),
      style: code.copyWith(color: colors.textPrimary),
    );
  }
}

class _TextMarkdownPreview extends StatelessWidget {
  const _TextMarkdownPreview({required this.model});

  final TextBlockModel model;

  @override
  Widget build(BuildContext context) {
    final source = model.node.markdown;
    return GestureDetector(
      key: const ValueKey('text-markdown-preview-surface'),
      behavior: HitTestBehavior.opaque,
      onTap: model.focusNode.requestFocus,
      child: source.isEmpty
          ? _EmptyTextMarkdownPreview(
              key: const ValueKey('text-markdown-preview'),
              model: model,
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
                  textStyle: _textStyle(model.node.style),
                ),
              },
              styleSheet: _styleSheet(context, model.node.style),
              imageBuilder: (uri, title, alt) => _buildImage(uri, alt),
              onTapLink: (_, href, _) => _openLink(context, href),
            ),
    );
  }
}

class _EmptyTextMarkdownPreview extends StatelessWidget {
  const _EmptyTextMarkdownPreview({required this.model, super.key});

  final TextBlockModel model;

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
            style: _textStyle(
              model.node.style,
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
  final base = _textStyle(style).copyWith(height: 1.5);
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

TextStyle _textStyle(TextNodeStyle style) => TextStyle(
  color: _colorFromHex(style.color),
  fontFamily: style.fontFamily,
  fontSize: style.fontSize,
);

Color _colorFromHex(String value) => Color(
  int.parse('ff${value.substring(1)}', radix: 16),
);

Widget _buildImage(Uri uri, String? alt) {
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.host.contains('%')) {
    return _TextImageError(alt: alt);
  }
  return Image.network(
    uri.toString(),
    width: 120,
    height: 80,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => _TextImageError(alt: alt),
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
