import 'dart:convert';
import 'dart:typed_data';

import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/canvas/tools/text/text_node.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/main.dart';
import 'package:beyond/utils/preset_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  late UrlLauncherPlatform originalLauncher;
  late _FakeUrlLauncher launcher;

  setUp(() async {
    SharedPreferencesAsyncWeb.registerWith(null);
    await SharedPreferencesAsync().remove(CanvasDocumentStore.key);
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
    expect(model.editing, isTrue);
    expect(find.byType(TextBlockControls), findsOneWidget);
    expect(find.byKey(const ValueKey('text-settings-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('text-settings-panel')).hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('text-block-rotate-control')),
      findsOneWidget,
    );
    expect(model.focusNode.hasFocus, isTrue);
    await tester.enterText(editor, 'focused typing');
    await tester.pump();
    expect(model.node.markdown, 'focused typing');
    expect(
      tester.getTopLeft(editor),
      const Offset(120, 200),
    );
    expect(find.byKey(const ValueKey('text-block-handle')), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('text-block-handle'))).dx,
      lessThan(tester.getTopLeft(editor).dx),
    );
    expect(
      find.byKey(const ValueKey('text-block-resize-handle')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const ValueKey('text-markdown-preview')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('text-block-handle')).hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('text-block-resize-handle')).hitTestable(),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('text-block-resize-handle')),
      findsNothing,
    );
    expect(find.byType(TextBlockControls), findsNothing);
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
    expect(find.byKey(const ValueKey('text-markdown-editor')), findsOneWidget);
    expect(find.byKey(const ValueKey('text-markdown-preview')), findsNothing);
  });

  testWidgets('text blocks move from their unfocused preview', (tester) async {
    await _addTextBlock(tester, const Offset(120, 200));
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    final block = find.byType(TextBlock);
    final model = tester.widget<TextBlock>(block).model;
    final originalPosition = model.node.position;
    const delta = Offset(80, 60);

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('text-markdown-preview-surface')),
      ),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(delta);
    await tester.pump();

    expect(model.node.position, originalPosition + delta);
    expect(model.editing, isFalse);
    expect(model.focusNode.hasFocus, isFalse);
    expect(find.byKey(const ValueKey('text-markdown-preview')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('text-block-handle')).hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('text-block-resize-handle')).hitTestable(),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextBlockControls), findsNothing);

    await gesture.up();
    await tester.pump();

    expect(model.editing, isFalse);
    expect(find.byKey(const ValueKey('text-markdown-preview')), findsOneWidget);
    expect(find.byType(TextBlockControls), findsNothing);
  });

  testWidgets(
    'text resizing enters manual mode, clamps, and scrolls overflow',
    (tester) async {
      await _addTextBlock(tester, const Offset(120, 200));
      final block = find.byType(TextBlock);
      final model = tester.widget<TextBlock>(block).model;
      final position = model.node.position;
      final style = model.node.style;
      final automaticHeight = tester.getSize(block).height;
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
      expect(originalHeight, greaterThan(automaticHeight));
      expect(model.node.height, isNull);
      final resizeHandle = find.byKey(
        const ValueKey('text-block-resize-handle'),
      );

      await tester.drag(resizeHandle, const Offset(80, 40));
      await tester.pump();

      expect(model.node.width, originalWidth + 80);
      expect(model.node.height, originalHeight + 40);
      expect(tester.getSize(block).width, originalWidth + 80);
      expect(tester.getSize(block).height, originalHeight + 40);
      expect(model.node.position, position);
      expect(model.node.markdown, source);
      expect(model.node.style, same(style));

      await tester.drag(resizeHandle, const Offset(-1000, -1000));
      await tester.pump();

      expect(model.node.width, textNodeMinimumWidth);
      expect(model.node.height, textNodeMinimumHeight);
      expect(tester.getSize(block).height, textNodeMinimumHeight);
      expect(model.scrollController.position.maxScrollExtent, greaterThan(0));
      expect(model.node.position, position);
      expect(model.node.markdown, source);
      expect(model.node.style, same(style));

      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(tester.getSize(block).height, textNodeMinimumHeight);
      expect(model.scrollController.position.maxScrollExtent, greaterThan(0));
    },
  );

  testWidgets('text resizing converts screen delta at canvas scale', (
    tester,
  ) async {
    await _addTextBlock(tester, const Offset(120, 200));
    final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    canvas.controller.updateScalebyDelta(1);
    await tester.pump();

    final originalSize = tester.getSize(find.byType(TextBlock));
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
    await tester.dragFrom(handlePosition, const Offset(80, 40));
    await tester.pump();

    expect(canvas.controller.scale, 2);
    expect(model.node.width, originalSize.width + 40);
    expect(model.node.height, originalSize.height + 20);
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
    await tester.pumpAndSettle();
    expect(model.focusNode.hasFocus, isTrue);
    expect(model.editing, isTrue);
    expect(find.byKey(const ValueKey('text-markdown-editor')), findsOneWidget);
    expect(find.byKey(const ValueKey('text-block-handle')), findsOneWidget);
    expect(find.byType(TextBlockControls), findsOneWidget);
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
    final networkImage = (secureImage as Padding).child! as Image;
    expect(networkImage.image, isA<NetworkImage>());
    expect(networkImage.width, double.infinity);
    expect(networkImage.height, isNull);
    expect(networkImage.fit, BoxFit.fitWidth);
    expect(insecureImage, isNot(isA<Image>()));
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
    final imagePadding =
        preview.imageBuilder!(
              Uri.parse('https://example.com/fails.png'),
              null,
              'failed',
            )
            as Padding;
    final image = imagePadding.child! as Image;
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
  });

  testWidgets('stored attachment images resolve asynchronously', (
    tester,
  ) async {
    const path = 'attachments/00000000-0000-4000-8000-000000000000.png';
    final store = _FakeAttachmentStore()
      ..files[path] = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
        'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
    await _addTextBlock(
      tester,
      const Offset(120, 200),
      attachmentStore: store,
    );
    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      '![stored]($path)',
    );

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    await tester.pump();

    expect(store.readPaths, <String>[path]);
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      isA<MemoryImage>(),
    );
  });

  testWidgets('missing attachments use the alt-labelled fallback', (
    tester,
  ) async {
    const path = 'attachments/00000000-0000-4000-8000-000000000000.webp';
    await _addTextBlock(
      tester,
      const Offset(120, 200),
      attachmentStore: _FakeAttachmentStore(),
    );
    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      '![missing]($path)',
    );

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'missing',
      ),
      findsOneWidget,
    );
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
    final imageLink = tester.widget<GestureDetector>(
      find.byWidgetPredicate(
        (widget) =>
            widget is GestureDetector &&
            widget.child is Padding &&
            (widget.child! as Padding).child is Image,
      ),
    );
    imageLink.onTap!();
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

    await tester.tap(
      find.byKey(const ValueKey('text-markdown-preview-surface')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('text-markdown-editor')), findsOneWidget);
  });

  testWidgets(
    'text settings change model style without changing source',
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
      expect(find.byType(TextBlockControls), findsOneWidget);
      expect(
        find.byKey(const ValueKey('text-settings-panel')).hitTestable(),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('text-settings-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('text-settings-panel')).hitTestable(),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('select-trigger')));
      await tester.pump();
      await tester.tap(find.text('Inter'));
      await tester.pumpAndSettle();

      expect(model.style.fontFamily, 'Inter');
      expect(model.node.markdown, source);
      expect(model.editing, isTrue);
      expect(model.focusNode.hasFocus, isFalse);
      expect(
        find.byKey(const ValueKey('text-markdown-editor')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('text-markdown-preview')),
        findsNothing,
      );
      expect(find.byType(TextBlockControls), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('text-settings-color')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('text-color-Black')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('text-color-Pink')),
        findsOneWidget,
      );

      final orangeSwatch = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Use Orange',
      );
      await tester.tap(orangeSwatch);
      await tester.pumpAndSettle();

      final orange = presetColors.singleWhere(
        (swatch) => swatch.label == 'Orange',
      );
      expect(model.style.color, colorToHex(orange.color));
      expect(model.node.markdown, source);
      expect(model.editing, isTrue);
      expect(find.byType(TextBlockControls), findsOneWidget);
    },
  );

  testWidgets('text editing is cleared by other blocks and empty canvas', (
    tester,
  ) async {
    await _addTextBlock(tester, const Offset(120, 200));
    final model = tester.widget<TextBlock>(find.byType(TextBlock)).model;
    expect(model.editing, isTrue);
    expect(find.byType(TextBlockControls), findsOneWidget);

    await tester.tap(find.text('Code'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(model.editing, isFalse);
    expect(find.byType(TextBlockControls), findsNothing);

    await tester.tapAt(const Offset(24, 550));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(model.editing, isFalse);
    expect(find.byType(TextBlockControls), findsNothing);
  });

  testWidgets('editing a second text rebinds closed text settings', (
    tester,
  ) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    final first = await _placeTextBlock(tester, const Offset(120, 200));
    final second = await _placeTextBlock(tester, const Offset(480, 360));

    await tester.tap(
      find.byKey(const ValueKey('text-settings-button')).hitTestable(),
    );
    await tester.pumpAndSettle();
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
      find.byKey(const ValueKey('text-settings-panel')).hitTestable(),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('text-settings-button')).hitTestable(),
    );
    await tester.pumpAndSettle();
    tester
        .widget<Select<String>>(find.byKey(const ValueKey('text-font-select')))
        .onChanged!
        .call('Roboto Mono');
    await tester.pump();
    expect(first.style.fontFamily, 'Roboto Mono');
    expect(second.style.fontFamily, 'Inter');
  });

  testWidgets('text nodes restore from the saved document', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    final first = await _placeTextBlock(tester, const Offset(120, 200));
    const firstSource = '# first\n\n**exact**';
    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      firstSource,
    );
    await tester.pump();

    final second = await _placeTextBlock(tester, const Offset(400, 360));
    const secondSource = '- second\n\n\$x^2\$';
    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      secondSource,
    );
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('text-block-handle')).hitTestable(),
      const Offset(60, 40),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('text-block-resize-handle')).hitTestable(),
      const Offset(40, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('text-settings-button')).hitTestable(),
    );
    await tester.pumpAndSettle();
    tester
        .widget<Select<String>>(find.byKey(const ValueKey('text-font-select')))
        .onChanged!
        .call('Inter');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('text-settings-color')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Use Orange',
      ),
    );
    await tester.pump();

    await tester.tapAt(const Offset(150, 220));
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await _pumpPastSave(tester);

    final preferences = SharedPreferencesAsync();
    final savedSource = await preferences.getString(CanvasDocumentStore.key);
    final savedDocument = CanvasDocument.fromJson(jsonDecode(savedSource!));
    expect(savedDocument.nodes, hasLength(2));
    expect(savedDocument.nodes.first.id, second.node.id);
    expect(savedDocument.nodes.last.id, first.node.id);
    expect(savedDocument.nodes.first.markdown, secondSource);
    expect(savedDocument.nodes.last.markdown, firstSource);
    expect(savedDocument.nodes.first.position, second.node.position);
    expect(savedDocument.nodes.first.width, second.node.width);
    expect(savedDocument.nodes.first.height, second.node.height);
    expect(savedDocument.nodes.first.style.fontFamily, 'Inter');
    expect(
      savedDocument.nodes.first.style.fontSize,
      second.node.style.fontSize,
    );
    expect(
      savedDocument.nodes.first.style.color,
      isNot(savedDocument.nodes.last.style.color),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    final restoredBlocks = tester.widgetList<TextBlock>(
      find.byType(TextBlock),
    );
    final restoredNodes = restoredBlocks.map((block) => block.model.node);
    expect(restoredNodes.map((node) => node.id).toList(), [
      second.node.id,
      first.node.id,
    ]);
    expect(restoredNodes.map((node) => node.markdown).toList(), [
      secondSource,
      firstSource,
    ]);
    expect(restoredNodes.map((node) => node.position).toList(), [
      second.node.position,
      first.node.position,
    ]);
    expect(restoredNodes.map((node) => node.width).toList(), [
      second.node.width,
      first.node.width,
    ]);
    expect(restoredNodes.map((node) => node.height).toList(), [
      second.node.height,
      first.node.height,
    ]);
    expect(restoredNodes.map((node) => node.style.fontFamily).toList(), [
      second.node.style.fontFamily,
      first.node.style.fontFamily,
    ]);
    expect(restoredNodes.map((node) => node.style.fontSize).toList(), [
      second.node.style.fontSize,
      first.node.style.fontSize,
    ]);
    expect(restoredNodes.map((node) => node.style.color).toList(), [
      second.node.style.color,
      first.node.style.color,
    ]);
    for (final block in restoredBlocks) {
      expect(block.model.editing, isFalse);
      expect(block.model.focusNode.hasFocus, isFalse);
    }
    expect(find.byType(TextBlockControls), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('malformed saved documents are preserved and reported', (
    tester,
  ) async {
    const invalid = '{"version":99,"nodes":[]}';
    final preferences = SharedPreferencesAsync();
    await preferences.setString(CanvasDocumentStore.key, invalid);

    await tester.pumpWidget(const BeyondApp());
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextBlock), findsNothing);
    expect(find.text('Could not load saved canvas'), findsOneWidget);
    expect(await preferences.getString(CanvasDocumentStore.key), invalid);

    await _placeTextBlock(tester, const Offset(120, 200));
    await tester.enterText(
      find.byKey(const ValueKey('text-markdown-editor')),
      'replacement',
    );
    await _pumpPastSave(tester);

    final replacement = await preferences.getString(CanvasDocumentStore.key);
    expect(
      CanvasDocument.fromJson(jsonDecode(replacement!)).nodes,
      hasLength(1),
    );
  });
}

Future<void> _addTextBlock(
  WidgetTester tester,
  Offset position, {
  AttachmentStore? attachmentStore,
}) async {
  await tester.pumpWidget(BeyondApp(attachmentStore: attachmentStore));
  await tester.pump();
  await tester.pump();
  await _placeTextBlock(tester, position);
}

Future<void> _pumpPastSave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 320));
  await tester.pump();
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

class _FakeAttachmentStore implements AttachmentStore {
  final files = <String, Uint8List>{};
  final readPaths = <String>[];

  @override
  Future<Uint8List> read(String path) async {
    readPaths.add(path);
    final bytes = files[path];
    if (bytes == null) throw StateError('missing attachment');
    return bytes;
  }

  @override
  Future<void> write(String path, Uint8List bytes) async {
    files[path] = bytes;
  }
}
