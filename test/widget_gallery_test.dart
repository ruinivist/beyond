import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dev/widget_gallery/main.dart';

void main() {
  testWidgets('gallery renders and its interactive examples work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const WidgetGalleryApp());
    await tester.pump();

    expect(find.text('Plane widget gallery'), findsOneWidget);
    expect(find.text('Existing'), findsWidgets);
    expect(find.text('Proposed'), findsWidgets);
    expect(find.text('A real editable text block'), findsOneWidget);

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('gallery-scroll')),
      matching: find.byType(Scrollable),
    ).first;
    final switchFinder = find.byType(SwitchListTile).first;
    await tester.scrollUntilVisible(switchFinder, 300, scrollable: scrollable);
    await tester.tap(switchFinder);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

    final settingsFinder = find.byKey(const ValueKey('open-settings'));
    await tester.scrollUntilVisible(
      settingsFinder,
      -300,
      scrollable: scrollable,
    );
    await tester.tap(settingsFinder);
    await tester.pumpAndSettle();
    expect(find.text('plane - dev build'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('plane - dev build'), findsNothing);
  });
}
