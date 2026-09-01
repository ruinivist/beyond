import 'dart:async';

import 'package:beyond/foundation/button.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/theme/starless.dart';
import 'package:beyond/widgets/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('theme selection updates the open app', (tester) async {
    await tester.pumpWidget(const _ThemeHost());
    await tester.tap(find.byKey(const ValueKey('open-settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interface'));
    await tester.pumpAndSettle();

    final select = tester.widget<Select<AppTheme>>(
      find.byKey(const ValueKey('theme-select')),
    );
    expect(select.options.map((option) => option.label), [
      'Starless Light',
      'Starless Dark',
    ]);
    select.onChanged!(AppTheme.starlessDark);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Select<AppTheme>>(
            find.byKey(const ValueKey('theme-select')),
          )
          .value,
      AppTheme.starlessDark,
    );
    expect(
      Theme.of(tester.element(find.byType(SettingsDialog))).brightness,
      Brightness.dark,
    );
    expect(
      BTheme.of(tester.element(find.byType(SettingsDialog))).syntaxTheme,
      isNotEmpty,
    );
  });

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

class _ThemeHost extends StatefulWidget {
  const _ThemeHost();

  @override
  State<_ThemeHost> createState() => _ThemeHostState();
}

class _ThemeHostState extends State<_ThemeHost> {
  AppTheme _theme = AppTheme.starlessLight;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: _theme.themeData,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('open-settings-button'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => SettingsDialog(
                appTheme: _theme,
                onAppThemeChanged: (theme) => setState(() => _theme = theme),
              ),
            ),
            child: const Text('Open settings'),
          ),
        ),
      ),
    );
  }
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
