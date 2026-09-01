import 'package:beyond/foundation/button.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/theme/starless.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('button uses BTheme defaults', (tester) async {
    final theme = starlessLightThemeData.extension<BTheme>()!;
    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: const Button(onPressed: _noop, child: Text('Primary')),
      ),
    );

    final textButton = tester.widget<TextButton>(find.byType(TextButton));
    expect(textButton.style!.backgroundColor!.resolve({}), theme.colors.accent);
    expect(
      textButton.style!.foregroundColor!.resolve({}),
      theme.colors.surface,
    );
    expect(
      textButton.style!.textStyle!.resolve({})!.fontSize,
      theme.typo.body.fontSize,
    );
    expect(
      (textButton.style!.shape!.resolve({})! as RoundedRectangleBorder)
          .borderRadius,
      theme.geo.radiusMedium,
    );
  });

  testWidgets('button variants use expanded default spacing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: const Button(
          variant: ButtonVariant.outline,
          onPressed: _noop,
          child: Text('Outline'),
        ),
      ),
    );

    final textButton = tester.widget<TextButton>(find.byType(TextButton));
    expect(textButton.style!.minimumSize!.resolve({}), const Size(0, 40));
    expect(
      textButton.style!.padding!.resolve({}),
      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  });

  testWidgets('ghost and link buttons keep their background state behavior', (
    tester,
  ) async {
    final theme = starlessLightThemeData.extension<BTheme>()!;

    for (final variant in [ButtonVariant.ghost, ButtonVariant.link]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: starlessLightThemeData,
          home: Button(
            variant: variant,
            onPressed: _noop,
            child: const Text('Button'),
          ),
        ),
      );

      final style = tester.widget<TextButton>(find.byType(TextButton)).style!;
      expect(style.backgroundColor!.resolve({}), Colors.transparent);
      expect(
        style.backgroundColor!.resolve({WidgetState.hovered}),
        variant == ButtonVariant.ghost
            ? theme.colors.surfaceHover
            : Colors.transparent,
      );
      expect(
        style.backgroundColor!.resolve({WidgetState.pressed}),
        variant == ButtonVariant.ghost
            ? theme.colors.surfacePressed
            : Colors.transparent,
      );
    }
  });
}

void _noop() {}
