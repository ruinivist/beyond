import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beyond/foundation/button.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/theme/starless_light.dart';

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
      (textButton.style!.shape!.resolve({}) as RoundedRectangleBorder)
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
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          backgroundColor: Colors.white,
          borderColor: Colors.black,
          borderRadius: BorderRadius.all(Radius.circular(20)),
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
    expect(
      textButton.style!.textStyle!.resolve({})!.fontWeight,
      FontWeight.w400,
    );
    expect(textButton.style!.backgroundColor!.resolve({}), Colors.white);
    expect(
      textButton.style!.side!.resolve({}),
      const BorderSide(color: Colors.black),
    );
    expect(
      (textButton.style!.shape!.resolve({}) as RoundedRectangleBorder)
          .borderRadius,
      BorderRadius.circular(20),
    );
  });

  testWidgets('ghost and link buttons honor background state overrides', (
    tester,
  ) async {
    const background = Colors.blue;
    const hover = Colors.lightBlue;
    const pressed = Colors.indigo;

    for (final variant in [ButtonVariant.ghost, ButtonVariant.link]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: starlessLightThemeData,
          home: Button(
            variant: variant,
            onPressed: _noop,
            backgroundColor: background,
            hoverColor: hover,
            pressedColor: pressed,
            child: const Text('Button'),
          ),
        ),
      );

      final style = tester.widget<TextButton>(find.byType(TextButton)).style!;
      expect(style.backgroundColor!.resolve({}), background);
      expect(style.backgroundColor!.resolve({WidgetState.hovered}), hover);
      expect(style.backgroundColor!.resolve({WidgetState.pressed}), pressed);
    }
  });
}

void _noop() {}
