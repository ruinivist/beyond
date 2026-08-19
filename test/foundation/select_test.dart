import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/theme/starless_light.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('select opens, navigates, selects, and dismisses', (
    tester,
  ) async {
    final theme = starlessLightThemeData.extension<BTheme>()!;
    var value = 'dart';
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
      (trigger.style!.shape!.resolve({})! as RoundedRectangleBorder)
          .borderRadius,
      theme.geo.radiusMedium,
    );
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
    expect(option.style!.textStyle!.resolve({}), theme.typo.body);
    final triggerRect = tester.getRect(
      find.byKey(const ValueKey('select-trigger')),
    );
    final popupOptionRect = tester.getRect(
      find.byKey(const ValueKey('select-option-0')),
    );
    expect(popupOptionRect.top, greaterThanOrEqualTo(triggerRect.bottom + 4));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      Focus.of(
        tester.element(find.byKey(const ValueKey('select-trigger'))),
      ).hasFocus,
      isTrue,
    );
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

  testWidgets('select ignores disabled options', (tester) async {
    var value = 'dart';
    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: StatefulBuilder(
          builder: (context, setState) => Select<String>(
            value: value,
            options: const [
              SelectOption(value: 'dart', label: 'Dart'),
              SelectOption(value: 'python', label: 'Python', enabled: false),
            ],
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('select-trigger')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('select-option-1')));
    await tester.pump();

    expect(value, 'dart');
  });

  testWidgets('select and menu match the widest option', (tester) async {
    Widget buildSelect(List<SelectOption<String>> options) {
      return MaterialApp(
        theme: starlessLightThemeData,
        home: Center(
          child: Select<String>(
            value: 'short',
            options: options,
            onChanged: (_) {},
          ),
        ),
      );
    }

    const shortOptions = [SelectOption(value: 'short', label: 'Short')];
    const wideOptions = [
      ...shortOptions,
      SelectOption(
        value: 'wide',
        label: 'A deliberately much wider option label',
      ),
    ];
    final trigger = find.byKey(const ValueKey('select-trigger'));

    await tester.pumpWidget(buildSelect(shortOptions));
    final shortWidth = tester.getSize(trigger).width;

    await tester.pumpWidget(buildSelect(wideOptions));
    final wideWidth = tester.getSize(trigger).width;
    expect(wideWidth, greaterThan(shortWidth));

    await tester.tap(trigger);
    await tester.pump();

    final menuMaterial = find.ancestor(
      of: find.byKey(const ValueKey('select-option-0')),
      matching: find.byType(Material),
    );
    expect(menuMaterial, findsOneWidget);
    expect(tester.getSize(menuMaterial).width, wideWidth);
  });
}
