// Verifies Beyond's shared context-menu interaction behavior.
// Exercises pointer opening and action dispatch under the app theme.

import 'package:beyond/theme/starless.dart';
import 'package:beyond/ui/common/context_menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------- Tests ----------

void main() {
  testWidgets('context menu opens from a secondary click', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: const Scaffold(
          body: BContextMenu(
            key: ValueKey('target'),
            groups: [
              [
                BContextMenuAction(
                  label: 'Duplicate',
                  icon: Icons.copy,
                  onPressed: _noop,
                ),
              ],
            ],
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('target')),
        matching: find.byType(InkWell),
      ),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Duplicate'), findsOneWidget);
  });
}

void _noop() {}
