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
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('select-trigger')),
          )
          .focusNode!
          .hasFocus,
      isFalse,
    );
  });

  testWidgets('select keeps focus on a focusable outside target', (
    tester,
  ) async {
    final outsideFocusNode = FocusNode();
    addTearDown(outsideFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Select<String>(
                  value: 'dart',
                  options: const [SelectOption(value: 'dart', label: 'Dart')],
                  onChanged: (_) {},
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: TextField(
                    key: const ValueKey('outside-focusable'),
                    focusNode: outsideFocusNode,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final trigger = find.byKey(const ValueKey('select-trigger'));
    await tester.tap(trigger);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('outside-focusable')));
    await tester.pump();

    expect(outsideFocusNode.hasFocus, isTrue);
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

  testWidgets(
    'searchable select orders, filters, selects, and clears its query',
    (tester) async {
      var value = 'dart';
      const options = [
        SelectOption(value: 'c', label: 'C'),
        SelectOption(value: 'cpp', label: 'C++'),
        SelectOption(value: 'dart', label: 'Dart'),
        SelectOption(value: 'go', label: 'Go'),
        SelectOption(value: 'java', label: 'Java', enabled: false),
        SelectOption(value: 'javascript', label: 'JavaScript'),
        SelectOption(value: 'python', label: 'Python'),
        SelectOption(value: 'rust', label: 'Rust'),
        SelectOption(value: 'typescript', label: 'TypeScript'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: starlessLightThemeData,
          home: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SearchableSelect<String>(
                value: value,
                options: options,
                preferredValues: const [
                  'python',
                  'typescript',
                  'dart',
                  'javascript',
                  'go',
                  'rust',
                  'python',
                ],
                searchHint: 'Search languages…',
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      );

      Future<void> open() async {
        await tester.tap(
          find.byKey(const ValueKey('searchable-select-trigger')),
        );
        await tester.pump();
      }

      void expectOption(int index, String label) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('searchable-select-option-$index')),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }

      await open();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('searchable-select-search')),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      for (final (index, label) in [
        'Python',
        'TypeScript',
        'Dart',
        'JavaScript',
        'Go',
        'Rust',
        'C',
        'C++',
        'Java',
      ].indexed) {
        expectOption(index, label);
      }

      await tester.enterText(
        find.byKey(const ValueKey('searchable-select-search')),
        'java',
      );
      await tester.pump();
      expectOption(0, 'Java');
      expectOption(1, 'JavaScript');
      expect(
        find.byKey(const ValueKey('searchable-select-option-2')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('searchable-select-option-0')),
      );
      await tester.pump();
      expect(value, 'dart');

      await tester.tap(
        find.byKey(const ValueKey('searchable-select-option-1')),
      );
      await tester.pumpAndSettle();
      expect(value, 'javascript');
      expect(
        find.byKey(const ValueKey('searchable-select-search')),
        findsNothing,
      );

      await open();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('searchable-select-search')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expectOption(0, 'Python');
      expectOption(1, 'TypeScript');

      final triggerFocusNode = tester
          .widget<TextButton>(
            find.byKey(const ValueKey('searchable-select-trigger')),
          )
          .focusNode!;
      await tester.tapAt(const Offset(1, 1));
      await tester.pump();
      expect(triggerFocusNode.hasFocus, isFalse);
    },
  );
}
