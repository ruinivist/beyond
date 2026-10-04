// Verifies native menu and dialog behavior with shared glass surfaces.
// Exercises keyboard navigation, scrolling, dismissal, and confirmation actions.

import 'package:elseplane/theme/starless.dart';
import 'package:elseplane/theme/theme.dart';
import 'package:elseplane/ui/common/context_menu.dart';
import 'package:elseplane/ui/common/glass_surface.dart';
import 'package:elseplane/ui/common/menu_surface.dart';
import 'package:elseplane/ui/common/select.dart';
import 'package:elseplane/ui/common/surface_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------- Tests ----------

void main() {
  testWidgets('glass dropdown retains keyboard selection, bounded scrolling, and dismissal', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      _app(
        Select<int>(
          value: selected,
          options: [for (var i = 0; i < 30; i++) SelectOption(value: i, label: 'Option $i')],
          onChanged: (value) => selected = value,
        ),
      ),
    );
    final trigger = find.byKey(const ValueKey('select-trigger'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.byType(GlassSurface), findsOneWidget);
    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(filter.backdropGroupKey, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(find.byType(MenuSurface), findsNothing);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final scroll = find.descendant(of: find.byType(MenuSurface), matching: find.byType(SingleChildScrollView));
    await tester.drag(scroll, const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option 29'));
    await tester.pumpAndSettle();
    expect(selected, 29);
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(780, 580));
    await tester.pumpAndSettle();
    expect(find.byType(MenuSurface), findsNothing);
  });

  testWidgets('glass searchable menu filters, scrolls, and preserves focus', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      _app(
        SearchableSelect<int>(
          value: selected,
          searchHint: 'Search languages',
          options: [
            for (var i = 0; i < 30; i++) SelectOption(value: i, label: 'Language ${i.toString().padLeft(2, '0')}'),
          ],
          onChanged: (value) => selected = value,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('searchable-select-trigger')));
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('searchable-select-search'));
    expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('Language 29'), findsOneWidget);
    await tester.enterText(search, 'Language 12');
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsOneWidget);
    await tester.tap(find.byType(MenuItemButton));
    await tester.pumpAndSettle();
    expect(selected, 12);
    expect(search, findsNothing);
  });

  testWidgets('glass context submenus and narrow confirmations retain native actions', (tester) async {
    var called = false;
    final controller = MenuController();
    await tester.pumpWidget(
      _app(
        ContextMenu(
          controller: controller,
          groups: [
            [
              ContextMenuAction(
                label: 'Arrange',
                icon: Icons.layers,
                groups: [
                  [ContextMenuAction(label: 'Bring forward', icon: Icons.arrow_upward, onPressed: () => called = true)],
                ],
              ),
            ],
          ],
          child: const SizedBox(width: 20, height: 20),
        ),
      ),
    );
    controller.open();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arrange'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassSurface), findsNWidgets(2));
    await tester.tap(find.text('Bring forward'));
    await tester.pumpAndSettle();
    expect(called, isTrue);
    expect(controller.isOpen, isFalse);

    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (context) => SurfaceConfirmationDialog(
                  title: const Text('Replace canvas?'),
                  content: const Text('Replace the active canvas with the imported canvas.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Replace')),
                  ],
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassSurface), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

// ---------- Harness ----------

Widget _app(Widget child) => MaterialApp(
  theme: starlessLightThemeData.copyWith(
    extensions: [starlessLightThemeData.extension<BTheme>()!.copyWith(surfaceStyle: SurfaceStyle.glass)],
  ),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);
