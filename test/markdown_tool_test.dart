import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:beyond/canvas/tools/markdown/markdown_block.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/main.dart';
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

  testWidgets('markdown blocks are editable, movable, and resizable', (
    tester,
  ) async {
    await _addMarkdownBlock(tester);

    final block = find.byType(MarkdownBlock);
    final model = tester.widget<MarkdownBlock>(block).model;
    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    final originalTopLeft = tester.getTopLeft(block);
    final originalCanvasOffset = canvas.controller.offset;

    expect(tester.getSize(block), const Size(560, 420));
    expect(originalTopLeft, const Offset(120, 90));
    expect(model.focusNode.hasFocus, isTrue);
    expect(find.byKey(const ValueKey('markdown-editor')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('markdown-block-header')),
      const Offset(60, 40),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    expect(tester.getTopLeft(block), originalTopLeft + const Offset(60, 40));
    expect(canvas.controller.offset, originalCanvasOffset);
    expect(model.selected, isTrue);

    final resizeHandle = find.byKey(
      const ValueKey('markdown-block-resize-handle'),
    );
    await tester.drag(resizeHandle, const Offset(-1000, -1000));
    await tester.pump();

    expect(tester.getSize(block), markdownBlockMinimumSize);

    await tester.tapAt(const Offset(24, 200));
    await tester.pump();
    expect(model.selected, isFalse);
  });

  testWidgets('preview renders GFM and math while preserving source', (
    tester,
  ) async {
    await _addMarkdownBlock(tester);
    const source = r'''# Heading

**bold** and inline $x^2$.

- [x] done

| A | B |
| - | - |
| 1 | 2 |

$$
x = \frac{-b}{2a}
$$''';

    await tester.enterText(
      find.byKey(const ValueKey('markdown-editor')),
      source,
    );
    await tester.tap(find.text('Preview'));
    await tester.pump();

    expect(find.byKey(const ValueKey('markdown-preview')), findsOneWidget);
    expect(find.text('Heading', findRichText: true), findsOneWidget);
    expect(find.byType(Math), findsNWidgets(2));
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    final markdown = tester.widget<Markdown>(
      find.byKey(const ValueKey('markdown-preview')),
    );
    final styleSheet = markdown.styleSheet!;
    final sourceSerif = BTheme.of(
      tester.element(find.byKey(const ValueKey('markdown-preview'))),
    ).typo.heading;
    expect(styleSheet.p!.fontFamily, sourceSerif.fontFamily);
    expect(styleSheet.p!.fontFamilyFallback, sourceSerif.fontFamilyFallback);
    expect(styleSheet.p!.fontSize, 16);
    expect(styleSheet.p!.fontWeight, isNull);
    expect(styleSheet.p!.height, 1.5);
    for (final (style, size, height) in [
      (styleSheet.h1, 24.0, 1.2),
      (styleSheet.h2, 22.0, 1.25),
      (styleSheet.h3, 20.0, 1.3),
      (styleSheet.h4, 18.0, 1.35),
      (styleSheet.h5, 17.0, 1.35),
      (styleSheet.h6, 16.0, 1.4),
    ]) {
      expect(style!.fontFamily, sourceSerif.fontFamily);
      expect(style.fontFamilyFallback, sourceSerif.fontFamilyFallback);
      expect(style.fontSize, size);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, height);
    }
    expect(styleSheet.tableHead!.fontSize, 14);
    expect(styleSheet.tableHead!.fontFamily, sourceSerif.fontFamily);
    expect(
      styleSheet.tableHead!.fontFamilyFallback,
      sourceSerif.fontFamilyFallback,
    );
    expect(styleSheet.tableHead!.fontWeight, FontWeight.w600);
    expect(styleSheet.tableHead!.height, 1.45);
    expect(styleSheet.tableBody!.fontFamily, sourceSerif.fontFamily);
    expect(
      styleSheet.tableBody!.fontFamilyFallback,
      sourceSerif.fontFamilyFallback,
    );
    expect(styleSheet.tableBody!.fontSize, 14);
    expect(styleSheet.tableBody!.fontWeight, isNull);
    expect(styleSheet.tableBody!.height, 1.45);

    await tester.tap(find.text('Edit'));
    await tester.pump();

    final model = tester
        .widget<MarkdownBlock>(find.byType(MarkdownBlock))
        .model;
    expect(model.controller.text, source);
    expect(model.focusNode.hasFocus, isTrue);
  });

  testWidgets('preview restricts images and external links', (tester) async {
    await _addMarkdownBlock(tester);
    const source = '''![secure](https://example.com/image.png)

![unsafe](http://example.com/image.png)

[safe](https://example.com) [unsafe link](javascript:alert(1))''';

    await tester.enterText(
      find.byKey(const ValueKey('markdown-editor')),
      source,
    );
    await tester.tap(find.text('Preview'));
    await tester.pump();

    final markdown = tester.widget<Markdown>(
      find.byKey(const ValueKey('markdown-preview')),
    );
    final secureImage = markdown.imageBuilder!(
      Uri.parse('https://example.com/image.png'),
      null,
      'secure',
    );
    expect((secureImage as Image).image, isA<NetworkImage>());
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);

    markdown.onTapLink!('safe', 'https://example.com', '');
    await tester.pump();
    expect(launcher.launched, ['https://example.com']);
    expect(
      launcher.options.single.mode,
      PreferredLaunchMode.externalApplication,
    );

    markdown.onTapLink!('unsafe link', 'javascript:alert(1)', '');
    await tester.pump();
    expect(launcher.launched, ['https://example.com']);
    expect(find.text('Could not open link'), findsOneWidget);
  });
}

Future<void> _addMarkdownBlock(WidgetTester tester) async {
  await tester.pumpWidget(const BeyondApp());
  await tester.pump();
  await tester.tap(find.text('Markdown'));
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
