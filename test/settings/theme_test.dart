// Verifies app-wide theme switching, storage, and failure handling.
// Exercises settings through the root app without changing canvas content.

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_background.dart';
import 'package:beyond/canvas/editor/canvas_page.dart';
import 'package:beyond/canvas/tools/text/text_tool.dart';
import 'package:beyond/main.dart';
import 'package:beyond/settings/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

import '../canvas/test_helpers.dart';

// ---------- Tests ----------

void main() {
  setUp(() async {
    SharedPreferencesAsyncWeb.registerWith(null);
    await SharedPreferencesAsync().remove(themePreferenceKey);
  });
  tearDown(() => SharedPreferencesAsync().remove(themePreferenceKey));

  testWidgets('theme switches live, persists, and keeps canvas content fixed', (tester) async {
    final preferences = SharedPreferencesAsync();
    expect(await loadThemeMode(preferences), ThemeMode.light);
    await preferences.setString(themePreferenceKey, 'unknown');
    expect(await loadThemeMode(preferences), ThemeMode.light);

    final store = TestCanvasDocumentStore(
      CanvasDocument(
        background: CanvasBackgroundKind.dotGrid,
        elements: [
          TextElementData(
            id: 'fixed-color',
            position: const Offset(80, 140),
            width: 420,
            height: 108,
            markdown: 'Fixed content color',
            style: const TextNodeStyle(fontFamily: 'Source Serif 4', color: '#201C1A'),
          ),
        ],
      ),
    );
    await tester.pumpWidget(BeyondApp(preferences: preferences, documentStore: store));
    await tester.pumpAndSettle();
    final canvasState = tester.state(find.byType(CanvasPage));
    final controller = tester.widget<LazyCanvas>(find.byType(LazyCanvas)).controller;
    final text = tester.widget<TextTool>(find.byType(TextTool)).model;
    final originalContent = text.node.toJson();

    await _openAppearance(tester);
    expect(_brightness(tester), Brightness.light);
    await _selectTheme(tester, 'Dark');
    expect(_brightness(tester), Brightness.dark);
    expect(await preferences.getString(themePreferenceKey), 'dark');
    expect(tester.state(find.byType(CanvasPage)), same(canvasState));
    expect(tester.widget<LazyCanvas>(find.byType(LazyCanvas)).controller, same(controller));
    expect(text.node.toJson(), originalContent);
    expect(store.persisted, isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      BeyondApp(initialThemeMode: await loadThemeMode(preferences), preferences: preferences, documentStore: store),
    );
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(CanvasPage))).brightness, Brightness.dark);
    await _openAppearance(tester);
    await _selectTheme(tester, 'Light');
    expect(_brightness(tester), Brightness.light);
    expect(await loadThemeMode(preferences), ThemeMode.light);
  });

  testWidgets('storage failure keeps the chosen theme and allows a later save', (tester) async {
    var fail = true;
    final preferences = _FailingPreferences(() => fail);
    expect(await loadThemeMode(preferences), ThemeMode.light);
    await tester.pumpWidget(BeyondApp(preferences: preferences, documentStore: TestCanvasDocumentStore()));
    await tester.pumpAndSettle();
    await _openAppearance(tester);
    await _selectTheme(tester, 'Dark');
    expect(_brightness(tester), Brightness.dark);
    expect(find.text('Could not save theme preference.'), findsOneWidget);

    fail = false;
    await _selectTheme(tester, 'Light');
    expect(await preferences.getString(themePreferenceKey), 'light');
  });
}

// ---------- Helpers ----------

Brightness _brightness(WidgetTester tester) => Theme.of(tester.element(find.byType(SettingsDialog))).brightness;

Future<void> _openAppearance(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('settings-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Appearance').last);
  await tester.pumpAndSettle();
}

Future<void> _selectTheme(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byKey(const ValueKey('theme-select')), matching: find.byType(TextButton)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

class _FailingPreferences extends SharedPreferencesAsync {
  _FailingPreferences(this.shouldFail);

  final bool Function() shouldFail;

  @override
  Future<String?> getString(String key) async {
    if (shouldFail()) throw StateError('Storage unavailable');
    return super.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    if (shouldFail()) throw StateError('Storage unavailable');
    await super.setString(key, value);
  }
}
