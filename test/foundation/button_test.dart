// Verifies the shared button's press and disabled behavior.
// Exercises the reusable button under Beyond themes.

import 'package:beyond/foundation/button.dart';
import 'package:beyond/theme/starless.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------- Tests ----------

void main() {
  testWidgets('button dispatches presses and supports disabling', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: BButton(
          onPressed: () => presses++,
          child: const Text('Save'),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    expect(presses, 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: const BButton(onPressed: null, child: Text('Save')),
      ),
    );
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
  });
}
