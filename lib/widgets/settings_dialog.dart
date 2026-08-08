import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final settings = context.appTheme.components.settings;
    return Dialog(
      backgroundColor: settings.background,
      surfaceTintColor: Colors.transparent,
      elevation: settings.elevation,
      shadowColor: settings.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(settings.radius),
        side: BorderSide(color: settings.divider),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: math.min(560.0, math.max(0.0, viewport.width - 32)),
        height: math.min(360.0, math.max(0.0, viewport.height - 32)),
        child: Row(
          children: [
            SizedBox(
              width: 152,
              child: Material(
                color: settings.navigationBackground,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      child: Text(
                        'Settings',
                        style: TextStyle(
                          color: settings.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Divider(height: 1, color: settings.divider),
                    ListTile(
                      selected: true,
                      selectedColor: settings.selectedForeground,
                      selectedTileColor: settings.selectedBackground,
                      hoverColor: settings.hoverBackground,
                      focusColor: settings.focus,
                      leading: const Icon(Icons.info_outline, size: 20),
                      title: const Text('About'),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, color: settings.divider),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'About',
                          style: TextStyle(
                            color: settings.foreground,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          style: ButtonStyle(
                            foregroundColor: WidgetStatePropertyAll(
                              settings.secondaryForeground,
                            ),
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.pressed)) {
                                return settings.pressedBackground;
                              }
                              if (states.contains(WidgetState.hovered)) {
                                return settings.hoverBackground;
                              }
                              return Colors.transparent;
                            }),
                            side: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.focused)
                                  ? BorderSide(color: settings.focus)
                                  : BorderSide.none,
                            ),
                          ),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'plane - dev build',
                      style: TextStyle(color: settings.secondaryForeground),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
