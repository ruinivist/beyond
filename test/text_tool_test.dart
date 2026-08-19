import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/canvas/tools/text/text_node.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
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
    expect(model.selected, isTrue);
    expect(find.byKey(const ValueKey('text-style-popover')), findsOneWidget);
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
    expect(
      find.byKey(const ValueKey('text-block-resize-handle')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const ValueKey('text-markdown-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('text-block-handle')), findsNothing);
    expect(
      find.byKey(const ValueKey('text-block-resize-handle')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('text-style-popover')), findsNothing);
  });

  testWidgets('text blocks move from their handle', (tester) async {
    await _addTextBlock(tester, const Offset(120, 200));

    final textBlock = find.byType(TextBlock);
    final handle = find.byKey(const ValueKey('text-block-handle'));
    final model = tester.widget<TextBlock>(textBlock).model;
    final originalTopLeft = tester.getTopLeft(textBlock);
    final originalWidth = model.node.width;
    const delta = Offset(80, 60);

    await tester.drag(handle, delta, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(tester.getTopLeft(textBlock), originalTopLeft + delta);
    expect(model.node.position, const Offset(200, 260));
    expect(model.node.width, originalWidth);
    expect(model.focusNode.hasFocus, isTrue);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.byKey(const ValueKey('text-block-handle')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('text-block-resize-handle')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('text-markdown-preview')), findsOneWidget);
  });

  testWidgets(
    'text width resizing is clamped and keeps node data independent',
    (
      tester,
    ) async {
      await _addTextBlock(tester, const Offset(120, 200));
      final block = find.byType(TextBlock);
      final model = tester.widget<TextBlock>(block).model;
      final position = model.node.position;
      final style = model.node.style;
      const source =
          'word word word word word word word word word word word word word '
          'word word word word word word word';

      await tester.enterText(
        find.byKey(const ValueKey('text-markdown-editor')),
        source,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      final originalHeight = tester.getSize(block).height;
      final originalWidth = model.node.width;
      final resizeHandle = find.byKey(
        const ValueKey('text-block-resize-handle'),
      );

      await tester.drag(resizeHandle, const Offset(80, 0));
      await tester.pump();

      expect(model.node.width, originalWidth + 80);
      expect(tester.getSize(block).width, originalWidth + 80);
      expect(model.node.position, position);
      expect(model.node.markdown, source);
      expect(model.node.style, same(style));

      await tester.drag(resizeHandle, const Offset(-1000, 0));
      await tester.pump();

      expect(model.node.width, textNodeMinimumWidth);
      expect(tester.getSize(block).height, greaterThan(originalHeight));
      expect(model.node.position, position);
      expect(model.node.markdown, source);
      expect(model.node.style, same(style));
    },
  );

  testWidgets('text width resizing converts screen delta at canvas scale', (
    tester,
  ) async {
    await _addTextBlock(tester, const Offset(120, 200));
    final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    canvas.controller.updateScalebyDelta(1);
    await tester.pump();

    final originalWidth = model.node.width;
    final child = canvas.controller.widgetsWithScreenPositions().single;
    final blockSize = tester.getSize(find.byType(TextBlock));
    final handleSize = tester.getSize(
      find.byKey(const ValueKey('text-block-resize-handle')),
    );
    final handlePosition =
        child.ssPosition +
        Offset(
          (model.node.width - handleSize.width / 2) * canvas.controller.scale,
          (blockSize.height - handleSize.height / 2) * canvas.controller.scale,
        );
    await tester.dragFrom(
      handlePosition,
      const Offset(80, 0),
    );
    await tester.pump();

    expect(canvas.controller.scale, 2);
    expect(model.node.width, originalWidth + 40);
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
    expect(
      styleSheet.p!.fontFamily,
      GoogleFonts.sourceSerif4().fontFamily,
    );
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

  testWidgets(
    'text style popover changes model style without changing source',
    (
      tester,
    ) async {
      await _addTextBlock(tester, const Offset(120, 200));
      const source = '**styled source**';
      await tester.enterText(
        find.byKey(const ValueKey('text-markdown-editor')),
        source,
      );

      final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
      expect(find.byKey(const ValueKey('text-style-popover')), findsOneWidget);

      tester
          .widget<Select<String>>(
            find.byKey(const ValueKey('text-font-select')),
          )
          .onChanged!
          .call('Inter');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(model.style.fontFamily, 'Inter');
      expect(model.node.markdown, source);
      expect(model.selected, isTrue);
      expect(model.focusNode.hasFocus, isFalse);
      expect(find.byKey(const ValueKey('text-markdown-editor')), findsNothing);
      expect(
        find.byKey(const ValueKey('text-markdown-preview')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('text-style-popover')), findsOneWidget);

      final accentSwatch = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Use accent color',
      );
      await tester.tap(accentSwatch);
      await tester.pump();

      final colors = BTheme.of(tester.element(find.byType(TextBlock))).colors;
      expect(model.style.color, colorToHex(colors.accent));
      expect(model.node.markdown, source);
      expect(model.selected, isTrue);
      expect(find.byKey(const ValueKey('text-style-popover')), findsOneWidget);

      final primarySemantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Use primary text color',
        ),
      );
      final accentSemantics = tester.widget<Semantics>(accentSwatch);
      expect(primarySemantics.properties.selected, isFalse);
      expect(accentSemantics.properties.selected, isTrue);
      final primaryButton = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip == 'Use primary text color',
        ),
      );
      expect(
        primaryButton.style!.side!.resolve({WidgetState.focused}),
        BorderSide(color: colors.focusRing, width: 2),
      );

      final preview = tester.widget<MarkdownBody>(
        find.byKey(const ValueKey('text-markdown-preview')),
      );
      expect(preview.styleSheet!.p!.fontFamily, GoogleFonts.inter().fontFamily);
      expect(
        preview.styleSheet!.code!.fontFamily,
        isNot(preview.styleSheet!.p!.fontFamily),
      );
      expect(
        preview.styleSheet!.h1!.fontSize,
        greaterThan(preview.styleSheet!.h2!.fontSize!),
      );
    },
  );

  testWidgets('text selection is cleared by other blocks and empty canvas', (
    tester,
  ) async {
    await _addTextBlock(tester, const Offset(120, 200));
    final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    expect(model.selected, isTrue);
    expect(find.byKey(const ValueKey('text-style-popover')), findsOneWidget);

    await tester.tap(find.text('Code'));
    await tester.pump();
    expect(model.selected, isFalse);
    expect(find.byKey(const ValueKey('text-style-popover')), findsNothing);

    await tester.tap(find.text('Markdown'));
    await tester.pump();
    expect(model.selected, isFalse);
    expect(find.byKey(const ValueKey('text-style-popover')), findsNothing);

    await tester.tapAt(const Offset(24, 550));
    await tester.pump();
    expect(model.selected, isFalse);
    expect(find.byKey(const ValueKey('text-style-popover')), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('selecting a second text rebinds the style popover', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    final first = await _placeTextBlock(tester, const Offset(120, 200));
    final second = await _placeTextBlock(tester, const Offset(480, 360));

    expect(
      tester.widget<TextStylePopover>(find.byType(TextStylePopover)).model,
      same(second),
    );
    tester
        .widget<Select<String>>(find.byKey(const ValueKey('text-font-select')))
        .onChanged!
        .call('Inter');
    await tester.pump();
    expect(second.style.fontFamily, 'Inter');
    expect(first.style.fontFamily, 'Source Serif 4');

    await tester.tapAt(const Offset(120, 200));
    await tester.pump();
    expect(
      tester.widget<TextStylePopover>(find.byType(TextStylePopover)).model,
      same(first),
    );
    tester
        .widget<Select<String>>(find.byKey(const ValueKey('text-font-select')))
        .onChanged!
        .call('Roboto Mono');
    await tester.pump();
    expect(first.style.fontFamily, 'Roboto Mono');
    expect(second.style.fontFamily, 'Inter');
  });
}

Future<void> _addTextBlock(WidgetTester tester, Offset position) async {
  await tester.pumpWidget(const BeyondApp());
  await tester.pump();
  await _placeTextBlock(tester, position);
}

Future<TextBlockModel> _placeTextBlock(
  WidgetTester tester,
  Offset position,
) async {
  await tester.tap(find.text('Text'));
  await tester.pump();
  await tester.tapAt(position);
  await tester.pump();
  await tester.pump();
  return tester.widget<TextBlock>(find.byType(TextBlock).last).model;
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
