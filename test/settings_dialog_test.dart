import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane/canvas/canvas_page.dart';

void main() {
  testWidgets('settings opens the about overlay', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CanvasPage()));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsNWidgets(2));
    expect(find.text('plane - dev build'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('plane - dev build'), findsNothing);
  });
}
