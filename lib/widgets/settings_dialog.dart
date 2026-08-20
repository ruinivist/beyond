import 'dart:math' as math;

import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final typo = theme.typo;
    return Dialog(
      backgroundColor: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: theme.geo.elevationMedium,
      shadowColor: colors.shadow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: theme.geo.radiusLarge,
        side: BorderSide(color: colors.borderSubtle),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: math.min(560, math.max(0, viewport.width - 32)),
        height: math.min(360, math.max(0, viewport.height - 32)),
        child: Row(
          children: [
            SizedBox(
              width: 152,
              child: Material(
                color: colors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      child: Text(
                        'Settings',
                        style: typo.title.copyWith(color: colors.textPrimary),
                      ),
                    ),
                    Divider(height: 1, color: colors.borderSubtle),
                    ListTile(
                      selected: true,
                      selectedColor: colors.accent,
                      selectedTileColor: colors.accentSoft,
                      hoverColor: colors.surfaceHover,
                      focusColor: colors.focusRing,
                      leading: const Icon(Icons.info_outline, size: 20),
                      title: const Text('About'),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, color: colors.borderSubtle),
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
                          style: typo.title.copyWith(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          style: ButtonStyle(
                            foregroundColor: WidgetStatePropertyAll(
                              colors.textSecondary,
                            ),
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.pressed)) {
                                return colors.surfacePressed;
                              }
                              if (states.contains(WidgetState.hovered)) {
                                return colors.surfaceHover;
                              }
                              return Colors.transparent;
                            }),
                            side: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.focused)
                                  ? BorderSide(color: colors.focusRing)
                                  : BorderSide.none,
                            ),
                          ),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'beyond - dev build',
                      style: typo.body.copyWith(color: colors.textSecondary),
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
