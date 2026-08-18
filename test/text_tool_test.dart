import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  late UrlLauncherPlatform originalLauncher;
  late _FakeUrlLauncher launcher;

  setUp(() {
    originalLauncher = UrlLauncherPlatform.instance;
    launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() => UrlLauncherPlatform.instance = originalLauncher);

  testWidgets('text places one focused source editor', (tester) async {
    await _addTextBlock(tester, const Offset(120, 200));
    final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    final editor = find.byKey(const ValueKey('text-markdown-editor'));

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(editor).focusNode, same(model.focusNode));
    expect(model.focusNode.hasFocus, isTrue);
    expect(FocusManager.instance.primaryFocus, same(model.focusNode));
    await tester.enterText(editor, 'focused typing');
    await tester.pump();
    expect(model.node.markdown, 'focused typing');
    expect(
      tester.getTopLeft(editor),
      const Offset(120, 200),
    );
    expect(find.byKey(const ValueKey('text-block-handle')), findsOneWidget);

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const ValueKey('text-markdown-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('text-block-handle')), findsNothing);
  });

  testWidgets('text blocks move from their handle', (tester) async {
    await _addTextBlock(tester, const Offset(120, 200));

    final textBlock = find.byType(TextBlock);
    final handle = find.byKey(const ValueKey('text-block-handle'));
    final model = tester.widget<TextBlock>(textBlock).model;
    final originalTopLeft = tester.getTopLeft(textBlock);
    const delta = Offset(80, 60);

    await tester.drag(handle, delta, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(tester.getTopLeft(textBlock), originalTopLeft + delta);
    expect(model.node.position, const Offset(200, 260));
    expect(model.focusNode.hasFocus, isTrue);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.byKey(const ValueKey('text-block-handle')), findsNothing);
    expect(find.byKey(const ValueKey('text-markdown-preview')), findsOneWidget);
  });

  testWidgets('text source survives preview edit cycles', (tester) async {
    await _addTextBlock(tester, const Offset(120, 200));
    const source = '**exact** _source_\n\n- [x] task';

    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      source,
    );
    final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    expect(model.node.markdown, source);

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    final preview = tester.widget<MarkdownBody>(
      find.byKey(const ValueKey('text-markdown-preview')),
    );
    expect(preview.data, source);

    await tester.tap(
      find.byKey(const ValueKey('text-markdown-preview-surface')),
    );
    await tester.pump();
    expect(model.focusNode.hasFocus, isTrue);
    expect(FocusManager.instance.primaryFocus, same(model.focusNode));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('text-markdown-editor')))
          .focusNode,
      same(model.focusNode),
    );
    expect(model.controller.text, source);
    expect(model.node.markdown, source);

    const editedSource = '$source\n\nedited';
    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      editedSource,
    );
    await tester.pump();
    expect(model.node.markdown, editedSource);

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(
      tester
          .widget<MarkdownBody>(
            find.byKey(const ValueKey('text-markdown-preview')),
          )
          .data,
      editedSource,
    );
  });

  testWidgets('text preview passes GFM, LaTeX, and semantic styles', (
    tester,
  ) async {
    await _addTextBlock(tester, const Offset(120, 200));
    const source = r'''
# Heading

**bold** and _italic_.

- [x] done

| A | B |
| - | - |
| 1 | 2 |

Inline $x^2$''';

    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      source,
    );
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    expect(find.text('Heading', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.byType(Math), findsOneWidget);

    final preview = tester.widget<MarkdownBody>(
      find.byKey(const ValueKey('text-markdown-preview')),
    );
    expect(preview.data, source);
    expect(preview.blockSyntaxes, hasLength(1));
    expect(preview.blockSyntaxes!.single, isA<LatexBlockSyntax>());
    expect(preview.inlineSyntaxes, hasLength(2));
    expect(
      preview.inlineSyntaxes,
      contains(isA<LatexInlineSyntax>()),
    );
    expect(preview.builders['latex'], isA<LatexElementBuilder>());

    final styleSheet = preview.styleSheet!;
    final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    expect(styleSheet.p!.fontSize, model.node.style.fontSize);
    expect(styleSheet.p!.fontFamily, model.node.style.fontFamily);
    expect(styleSheet.h1!.fontSize, greaterThan(styleSheet.h2!.fontSize!));
    expect(styleSheet.h2!.fontSize, greaterThan(styleSheet.h3!.fontSize!));
    expect(styleSheet.h3!.fontSize, greaterThan(styleSheet.h4!.fontSize!));
    expect(styleSheet.h4!.fontSize, greaterThan(styleSheet.h5!.fontSize!));
    expect(
      styleSheet.h5!.fontSize,
      greaterThanOrEqualTo(styleSheet.h6!.fontSize!),
    );
    expect(styleSheet.strong!.fontWeight, isNotNull);
    expect(styleSheet.em!.fontStyle, FontStyle.italic);
    expect(styleSheet.checkbox!.color, isNotNull);
    expect(styleSheet.tableHead!.fontWeight, isNotNull);
    expect(styleSheet.tableBody!.fontSize, lessThan(styleSheet.p!.fontSize!));
  });

  testWidgets('text preview keeps links safe and images restricted', (
    tester,
  ) async {
    await _addTextBlock(tester, const Offset(120, 200));
    const source = '''
![secure](https://example.com/image.png)

![unsafe](http://example.com/image.png)

![malformed](<https://[bad> "broken")

[safe](https://example.com) [unsafe link](javascript:alert(1))''';

    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      source,
    );
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    final preview = tester.widget<MarkdownBody>(
      find.byKey(const ValueKey('text-markdown-preview')),
    );
    final secureImage = preview.imageBuilder!(
      Uri.parse('https://example.com/image.png'),
      null,
      'secure',
    );
    final insecureImage = preview.imageBuilder!(
      Uri.parse('http://example.com/image.png'),
      null,
      'unsafe',
    );
    expect((secureImage as Image).image, isA<NetworkImage>());
    expect(insecureImage, isNot(isA<Image>()));
    expect(find.byIcon(Icons.broken_image_outlined), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label == 'malformed' ||
                widget.properties.label == 'unsafe'),
      ),
      findsNWidgets(2),
    );

    preview.onTapLink!('safe', 'https://example.com', '');
    await tester.pump();
    expect(launcher.launched, ['https://example.com']);
    expect(
      launcher.options.single.mode,
      PreferredLaunchMode.externalApplication,
    );

    preview.onTapLink!('unsafe link', 'javascript:alert(1)', '');
    await tester.pump();
    expect(launcher.launched, ['https://example.com']);
    expect(find.text('Could not open link'), findsOneWidget);
  });

  testWidgets('failed images use an alt-labelled broken-image fallback', (
    tester,
  ) async {
    await _addTextBlock(tester, const Offset(120, 200));
    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      '![failed](https://example.com/fails.png)',
    );
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    final preview = tester.widget<MarkdownBody>(
      find.byKey(const ValueKey('text-markdown-preview')),
    );
    final image =
        preview.imageBuilder!(
              Uri.parse('https://example.com/fails.png'),
              null,
              'failed',
            )
            as Image;
    final fallback = image.errorBuilder!(
      tester.element(find.byKey(const ValueKey('text-markdown-preview'))),
      Exception('failed image'),
      StackTrace.current,
    );
    await tester.pumpWidget(MaterialApp(home: fallback));

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'failed',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('rendered link gestures do not enter text editing', (
    tester,
  ) async {
    await _addTextBlock(tester, const Offset(120, 200));
    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      '[safe](https://example.com) [unsafe](javascript:alert(1))',
    );
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    final links = find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.textSpan?.toPlainText() == 'safe unsafe',
    );
    expect(links, findsOneWidget);
    final linksTopLeft = tester.getTopLeft(links);
    final renderedLinks = tester.renderObject<RenderParagraph>(links);
    Offset linkPoint(int start, int end) =>
        linksTopLeft +
        renderedLinks
            .getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: end),
            )
            .single
            .toRect()
            .center;

    await tester.tapAt(linkPoint(0, 4));
    await tester.pump();
    expect(launcher.launched, ['https://example.com']);
    expect(model.focusNode.hasFocus, isFalse);
    expect(find.byType(TextField), findsNothing);

    await tester.tapAt(linkPoint(5, 11));
    await tester.pump();
    expect(launcher.launched, ['https://example.com']);
    expect(model.focusNode.hasFocus, isFalse);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Could not open link'), findsOneWidget);
  });

  testWidgets('linked images keep their enclosing link gesture', (
    tester,
  ) async {
    await _addTextBlock(tester, const Offset(120, 200));
    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      '[![linked](https://example.com/image.png "title")](https://example.com/image)',
    );
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    final image = find.byType(Image);
    expect(image, findsOneWidget);
    await tester.tap(image);
    await tester.pump();

    expect(launcher.launched, ['https://example.com/image']);
    expect(model.focusNode.hasFocus, isFalse);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('empty text preview has a clickable minimum area', (
    tester,
  ) async {
    await _addTextBlock(tester, const Offset(120, 200));
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    final block = find.byType(TextBlock);
    expect(tester.getSize(block).height, greaterThanOrEqualTo(52));
    expect(find.text('Click to edit'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('text-markdown-preview-surface')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('text-markdown-editor')), findsOneWidget);
  });
}

Future<void> _addTextBlock(WidgetTester tester, Offset position) async {
  await tester.pumpWidget(const BeyondApp());
  await tester.pump();
  await tester.tap(find.text('Text'));
  await tester.pump();
  await tester.tapAt(position);
  await tester.pump();
  await tester.pump();
}

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final launched = <String>[];
  final options = <LaunchOptions>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    this.options.add(options);
    return true;
  }
}
