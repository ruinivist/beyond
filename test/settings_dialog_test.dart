import 'dart:async';

import 'package:beyond/foundation/button.dart';
import 'package:beyond/theme/starless_light.dart';
import 'package:beyond/widgets/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'export disables both actions until it completes',
    (tester) async {
      final exportCompleted = Completer<void>();
      var exportCalls = 0;

      await _openCanvasSettings(
        tester,
        onImport: () async => true,
        onExport: () {
          exportCalls++;
          return exportCompleted.future;
        },
      );

      expect(
        find.byKey(const ValueKey('canvas-import-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('canvas-export-button')),
        findsOneWidget,
      );
      expect(find.text('Import canvas'), findsOneWidget);
      expect(find.text('Export canvas'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('canvas-export-button')));
      await tester.pump();

      expect(exportCalls, 1);
      expect(_button(tester, 'canvas-import-button').onPressed, isNull);
      expect(_button(tester, 'canvas-export-button').onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('canvas-export-button')));
      await tester.pump();
      expect(exportCalls, 1);

      exportCompleted.complete();
      await tester.pumpAndSettle();

      expect(find.byType(SettingsDialog), findsOneWidget);
    },
  );

  testWidgets('import closes only when the callback succeeds', (tester) async {
    var imported = true;
    var importCalls = 0;

    Future<bool> onImport() async {
      importCalls++;
      return imported;
    }

    await _openCanvasSettings(
      tester,
      onImport: onImport,
      onExport: () async {},
    );

    await tester.tap(find.byKey(const ValueKey('canvas-import-button')));
    await tester.pumpAndSettle();

    expect(importCalls, 1);
    expect(find.byType(SettingsDialog), findsNothing);

    imported = false;
    await _openCanvasSettings(
      tester,
      onImport: onImport,
      onExport: () async {},
    );
    await tester.tap(find.byKey(const ValueKey('canvas-import-button')));
    await tester.pumpAndSettle();

    expect(importCalls, 2);
    expect(find.byType(SettingsDialog), findsOneWidget);
  });
}

Button _button(WidgetTester tester, String key) =>
    tester.widget<Button>(find.byKey(ValueKey(key)));

Future<void> _openCanvasSettings(
  WidgetTester tester, {
  required Future<bool> Function() onImport,
  required Future<void> Function() onExport,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: starlessLightThemeData,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('open-settings-button'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => SettingsDialog(
                onImportCanvas: onImport,
                onExportCanvas: onExport,
              ),
            ),
            child: const Text('Open settings'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-settings-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Canvas').last);
  await tester.pumpAndSettle();
}
