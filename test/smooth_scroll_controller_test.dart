import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane/canvas/smooth_scroll_controller.dart';

void main() {
  testWidgets('wheel scrolling eases, accumulates, and clamps', (tester) async {
    final controller = SmoothScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 100,
          child: ListView.builder(
            controller: controller,
            itemCount: 20,
            itemExtent: 50,
            itemBuilder: (_, index) => Text('$index'),
          ),
        ),
      ),
    );

    controller.position.pointerScroll(100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(controller.offset, inExclusiveRange(0, 100));

    controller.position.pointerScroll(100);
    await tester.pump();
    await tester.pump(smoothScrollDuration);
    expect(controller.offset, 200);

    controller.position.pointerScroll(-1000);
    await tester.pump();
    await tester.pump(smoothScrollDuration);
    expect(controller.offset, 0);

    controller.position.pointerScroll(2000);
    await tester.pump();
    await tester.pump(smoothScrollDuration);
    expect(controller.offset, controller.position.maxScrollExtent);
  });
}
