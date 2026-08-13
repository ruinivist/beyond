import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beyond/main.dart';

void main() {
  testWidgets('settings opens the about overlay', (tester) async {
    await tester.pumpWidget(const BeyondApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsNWidgets(2));
    expect(find.text('beyond - dev build'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('beyond - dev build'), findsNothing);
  });
}
