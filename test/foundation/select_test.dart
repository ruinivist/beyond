import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/theme/starless_light.dart';

void main() {
  testWidgets('select opens, navigates, selects, and dismisses', (
    tester,
  ) async {
    final theme = starlessLightThemeData.extension<BTheme>()!;
    var value = 'dart';
    const callerStyle = TextStyle(
      fontFamily: 'CallerFont',
      fontFamilyFallback: ['CallerFallback'],
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    final options = [
      const SelectOption(value: 'dart', label: 'Dart'),
      const SelectOption(value: 'python', label: 'Python'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: Select<String>(
              value: value,
              options: options,
              onChanged: (next) => setState(() => value = next),
              textStyle: callerStyle,
            ),
          ),
        ),
      ),
    );

    final trigger = tester.widget<TextButton>(
      find.byKey(const ValueKey('select-trigger')),
    );
    expect(trigger.style!.backgroundColor!.resolve({}), theme.colors.surface);
    expect(
      trigger.style!.backgroundColor!.resolve({WidgetState.hovered}),
      theme.colors.surfaceHover,
    );
    expect(
      trigger.style!.backgroundColor!.resolve({WidgetState.focused}),
      theme.colors.surfaceHover,
    );
    expect(
      trigger.style!.backgroundColor!.resolve({WidgetState.pressed}),
      theme.colors.surfacePressed,
    );
    expect(
      trigger.style!.side!.resolve({WidgetState.focused}),
      BorderSide(color: theme.colors.borderSubtle),
    );
    expect(
      (trigger.style!.shape!.resolve({}) as RoundedRectangleBorder)
          .borderRadius,
      theme.geo.radiusMedium,
    );
    _expectTypography(trigger.style!.textStyle!.resolve({})!, callerStyle);

    await tester.tap(find.byKey(const ValueKey('select-trigger')));
    await tester.pump();
    expect(find.byKey(const ValueKey('select-option-1')), findsOneWidget);
    final menu = tester.widget<MenuAnchor>(
      find.byKey(const ValueKey('select-menu')),
    );
    expect(menu.style!.elevation!.resolve({}), theme.geo.elevationMedium);
    final option = tester.widget<MenuItemButton>(
      find.byKey(const ValueKey('select-option-0')),
    );
    _expectTypography(option.style!.textStyle!.resolve({})!, callerStyle);
    final triggerRect = tester.getRect(
      find.byKey(const ValueKey('select-trigger')),
    );
    final popupOptionRect = tester.getRect(
      find.byKey(const ValueKey('select-option-0')),
    );
    expect(popupOptionRect.top, greaterThanOrEqualTo(triggerRect.bottom + 4));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.byKey(const ValueKey('select-option-0')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(value, 'python');
    expect(find.byKey(const ValueKey('select-option-1')), findsNothing);
    expect(find.text('Python'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('select-trigger')));
    await tester.pump();
    await tester.tapAt(const Offset(1, 1));
    await tester.pump();
    expect(find.byKey(const ValueKey('select-option-0')), findsNothing);
  });

  testWidgets('select honors geometry overrides', (tester) async {
    final radius = BorderRadius.circular(20);
    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: Select<String>(
          value: 'dart',
          options: const [SelectOption(value: 'dart', label: 'Dart')],
          onChanged: (_) {},
          borderRadius: radius,
          popupElevation: 3,
        ),
      ),
    );

    final trigger = tester.widget<TextButton>(
      find.byKey(const ValueKey('select-trigger')),
    );
    expect(
      (trigger.style!.shape!.resolve({}) as RoundedRectangleBorder)
          .borderRadius,
      radius,
    );

    await tester.tap(find.byKey(const ValueKey('select-trigger')));
    await tester.pump();
    final menu = tester.widget<MenuAnchor>(
      find.byKey(const ValueKey('select-menu')),
    );
    expect(menu.style!.elevation!.resolve({}), 3);
  });
}

void _expectTypography(TextStyle actual, TextStyle expected) {
  expect(actual.fontFamily, expected.fontFamily);
  expect(actual.fontFamilyFallback, expected.fontFamilyFallback);
  expect(actual.fontSize, expected.fontSize);
  expect(actual.fontWeight, expected.fontWeight);
  expect(actual.height, expected.height);
}
