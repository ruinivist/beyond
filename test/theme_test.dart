import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:beyond/main.dart';
import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:beyond/theme/starless_light.dart';
import 'package:re_editor/re_editor.dart';
import 'package:scribble/scribble.dart';
import 'package:beyond/foundation/theme.dart';

const _testColors = BColors(
  surface: Colors.black,
  surfaceRaised: Colors.black,
  surfaceSubtle: Colors.black,
  surfaceHover: Colors.black,
  surfacePressed: Colors.black,
  textPrimary: Colors.black,
  textSecondary: Colors.black,
  textMuted: Colors.black,
  borderSubtle: Colors.black,
  accent: Colors.black,
  accentHover: Colors.black,
  accentPressed: Colors.black,
  accentSoft: Colors.black,
  accentSubtle: Colors.black,
  focusRing: Colors.black,
  shadow: Colors.black,
  scrim: Colors.black,
);
const _testGeo = BGeo(
  radiusSmall: BorderRadius.all(Radius.circular(4)),
  radiusMedium: BorderRadius.all(Radius.circular(8)),
  radiusLarge: BorderRadius.all(Radius.circular(10)),
  elevationLow: 4,
  elevationMedium: 8,
  elevationHigh: 12,
);
const _testTheme = BTheme(
  colors: _testColors,
  typo: BTypo(
    display: TextStyle(),
    heading: TextStyle(),
    title: TextStyle(),
    body: TextStyle(),
    label: TextStyle(),
    code: TextStyle(),
  ),
  geo: _testGeo,
);

void main() {
  testWidgets('BTheme.of fails without a registered extension', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(
      () => BTheme.of(tester.element(find.byType(SizedBox))),
      throwsFlutterError,
    );
  });

  test('BTheme supports copyWith and interpolation', () {
    final copy = _testTheme.copyWith(typo: _testTheme.typo, geo: _testGeo);
    expect(copy.colors, same(_testTheme.colors));
    expect(copy.geo, same(_testGeo));
    expect(_testTheme.lerp(_testTheme, 0.5), isA<BTheme>());

    const other = BGeo(
      radiusSmall: BorderRadius.all(Radius.circular(8)),
      radiusMedium: BorderRadius.all(Radius.circular(12)),
      radiusLarge: BorderRadius.all(Radius.circular(14)),
      elevationLow: 8,
      elevationMedium: 12,
      elevationHigh: 16,
    );
    final midpoint = _testGeo.lerp(other, 0.5);
    expect(midpoint.radiusSmall.topLeft.x, 6);
    expect(midpoint.elevationMedium, 10);
  });

  testWidgets('Starless Light maps onto the current UI', (tester) async {
    final colors = starlessLight.colors;
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    final canvas = tester.widget<LazyCanvas>(find.byType(LazyCanvas));
    final background = canvas.controller.background as DotGridBackground;
    expect(background.backgroundColor, starlessCanvasBackground);
    expect(background.dotColor, starlessCanvasGrid);
    expect(background.spacing, 50);
    expect(background.size, 2);

    final toolbar = tester.widget<Material>(
      find.byKey(const ValueKey('toolbar-surface')),
    );
    expect(toolbar.color, colors.surfaceRaised);
    expect(toolbar.shadowColor, colors.shadow);
    expect(toolbar.elevation, starlessLight.geo.elevationLow);
    expect(
      (toolbar.shape as RoundedRectangleBorder).borderRadius,
      starlessLight.geo.radiusMedium,
    );

    await tester.tap(find.text('Text'));
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.style!.fontFamily, starlessLight.typo.heading.fontFamily);
    expect(
      textField.style!.fontFamilyFallback,
      starlessLight.typo.heading.fontFamilyFallback,
    );
    expect(textField.style!.fontSize, 20);
    expect(textField.style!.height, 1.3);
    expect(
      textField.decoration!.hintStyle!.fontFamily,
      starlessLight.typo.heading.fontFamily,
    );
    expect(textField.decoration!.hintStyle!.fontSize, 18);
    expect(textField.decoration!.hintStyle!.height, 1.5);

    await tester.tap(find.text('Pen'));
    await tester.pump();
    final penButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Pen'),
    );
    expect(penButton.style!.backgroundColor!.resolve({}), colors.accentSoft);
    final pen = tester.widget<Scribble>(find.byType(Scribble));
    expect(
      (pen.notifier.value as Drawing).selectedColor,
      colors.accent.toARGB32(),
    );

    await tester.tap(find.text('Pen'));
    await tester.tap(find.text('Code'));
    await tester.pump();
    final codeSurface = tester.widget<Material>(
      find.byKey(const ValueKey('code-block-surface')),
    );
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(codeSurface.color, colors.surface);
    expect(editor.style!.cursorColor, colors.accent);
    expect(editor.style!.selectionColor, colors.accentSubtle);
    expect(editor.style!.fontFamily, starlessLight.typo.code.fontFamily);
    expect(
      editor.style!.fontFamilyFallback,
      starlessLight.typo.code.fontFamilyFallback,
    );
    final lineNumbers = tester.widget<DefaultCodeLineNumber>(
      find.byType(DefaultCodeLineNumber),
    );
    expect(
      lineNumbers.textStyle!.fontFamily,
      starlessLight.typo.code.fontFamily,
    );
    expect(
      lineNumbers.focusedTextStyle!.fontFamily,
      starlessLight.typo.code.fontFamily,
    );
    expect(
      editor.style!.codeTheme!.theme,
      CodeLanguage.dart.theme(starlessSyntaxTheme)!.theme,
    );

    await tester.tap(find.text('Markdown'));
    await tester.pump();
    final markdownSurface = tester.widget<Material>(
      find.byKey(const ValueKey('markdown-block-surface')),
    );
    expect(markdownSurface.color, colors.surface);
    expect(find.byKey(const ValueKey('markdown-mode-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    final about = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'About'),
    );
    expect(dialog.backgroundColor, colors.surfaceRaised);
    expect(dialog.shadowColor, colors.shadow);
    expect(dialog.elevation, starlessLight.geo.elevationMedium);
    expect(
      (dialog.shape as RoundedRectangleBorder).borderRadius,
      starlessLight.geo.radiusLarge,
    );
    expect(about.selectedTileColor, colors.accentSoft);
    expect(about.selectedColor, colors.accent);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'About' &&
            widget.style?.fontSize == 14,
      ),
      findsOneWidget,
    );
  });

  test('syntax token styles inherit the editor font', () {
    for (final language in CodeLanguage.values) {
      final theme = language.theme(starlessSyntaxTheme);
      if (theme == null) continue;

      for (final style in theme.theme.values) {
        expect(style.fontFamily, isNull);
      }
    }
  });

  test('ThemeData keeps compact UI typography', () {
    final textTheme = starlessLightThemeData.textTheme;
    expect(textTheme.bodyLarge!.fontFamily, starlessLight.typo.body.fontFamily);
    expect(textTheme.bodyLarge!.fontSize, 14);
    expect(
      textTheme.titleLarge!.fontFamily,
      starlessLight.typo.title.fontFamily,
    );
    expect(textTheme.titleLarge!.fontSize, 14);
    expect(textTheme.titleLarge!.fontWeight, FontWeight.w600);
    expect(
      starlessLightThemeData.tooltipTheme.textStyle!.fontFamily,
      starlessLight.typo.body.fontFamily,
    );
    expect(starlessLightThemeData.tooltipTheme.textStyle!.fontSize, 12);
  });
}
