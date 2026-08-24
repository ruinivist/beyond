import 'package:beyond/foundation/discrete_slider.dart';
import 'package:beyond/theme/starless_light.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('discrete slider disables input without a change callback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: const Scaffold(
          body: DiscreteSlider(value: 9, onChanged: null),
        ),
      ),
    );

    expect(
      tester
          .widget<Slider>(find.byKey(const ValueKey('discrete-slider')))
          .onChanged,
      isNull,
    );
  });

  testWidgets('slider stays discrete for keyboard and pointer input', (
    tester,
  ) async {
    var value = 9;
    final changes = <int>[];
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: DiscreteSlider(
                value: value,
                focusNode: focusNode,
                onChanged: (next) {
                  changes.add(next);
                  setState(() => value = next);
                },
              ),
            ),
          ),
        ),
      ),
    );

    final sliderFinder = find.byKey(const ValueKey('discrete-slider'));
    final slider = tester.widget<Slider>(sliderFinder);
    expect(slider.min, 1);
    expect(slider.max, 20);
    expect(slider.divisions, 19);
    expect(slider.label, '9 px');
    final sliderTheme = tester.widget<SliderTheme>(find.byType(SliderTheme));
    expect(sliderTheme.data.trackHeight, 4);
    expect(
      sliderTheme.data.thumbShape!.getPreferredSize(true, true),
      const Size.square(16),
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    final valueBeforeKeyboard = value;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(value, valueBeforeKeyboard + 1);

    changes.clear();
    await tester.drag(sliderFinder, const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(changes, isNotEmpty);
    expect(changes.every((next) => next >= 1 && next <= 20), isTrue);
    expect(value, greaterThan(10));
  });

  testWidgets('value pill appears only during pointer dragging', (
    tester,
  ) async {
    var value = 9;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DiscreteSlider(
              value: value,
              focusNode: focusNode,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    final slider = find.byKey(const ValueKey('discrete-slider'));
    expect(
      tester
          .widget<SliderTheme>(find.byType(SliderTheme))
          .data
          .showValueIndicator,
      ShowValueIndicator.onDrag,
    );
    final indicator = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == '_ValueIndicatorRenderObjectWidget',
    );
    expect(indicator, findsOneWidget);
    expect(indicator, paintsNothing);

    final gesture = await tester.startGesture(tester.getCenter(slider));
    await tester.pumpAndSettle();
    expect(indicator, isNot(paintsNothing));

    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
    expect(indicator, paintsNothing);
  });
}
