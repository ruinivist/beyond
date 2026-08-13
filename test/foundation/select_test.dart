import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beyond/foundation/select.dart';

void main() {
  testWidgets('select opens, navigates, selects, and dismisses', (
    tester,
  ) async {
    var value = 'dart';
    final options = [
      const SelectOption(value: 'dart', label: 'Dart'),
      const SelectOption(value: 'python', label: 'Python'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: Select<String>(
              value: value,
              options: options,
              onChanged: (next) => setState(() => value = next),
              textStyle: const TextStyle(fontSize: 14),
              foregroundColor: Colors.black,
              backgroundColor: Colors.transparent,
              popupColor: Colors.white,
              borderColor: Colors.black,
              hoverColor: Colors.grey,
              pressedColor: Colors.grey,
            ),
          ),
        ),
      ),
    );

    final trigger = tester.widget<TextButton>(
      find.byKey(const ValueKey('select-trigger')),
    );
    expect(
      trigger.style!.backgroundColor!.resolve({WidgetState.focused}),
      Colors.grey,
    );
    expect(
      trigger.style!.side!.resolve({WidgetState.focused}),
      const BorderSide(color: Colors.black),
    );

    await tester.tap(find.byKey(const ValueKey('select-trigger')));
    await tester.pump();
    expect(find.byKey(const ValueKey('select-option-1')), findsOneWidget);
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
}
