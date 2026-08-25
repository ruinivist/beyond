import 'dart:math' as math;

import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/foundation/button.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    this.canvasBackgroundKind = CanvasBackgroundKind.dotGrid,
    this.onCanvasBackgroundChanged,
    this.onImportCanvas,
    this.onExportCanvas,
    super.key,
  });

  final CanvasBackgroundKind canvasBackgroundKind;
  final ValueChanged<CanvasBackgroundKind>? onCanvasBackgroundChanged;
  final Future<bool> Function()? onImportCanvas;
  final Future<void> Function()? onExportCanvas;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

enum _SettingsSection { about, canvas }

class _SettingsDialogState extends State<SettingsDialog> {
  late CanvasBackgroundKind _canvasBackgroundKind = widget.canvasBackgroundKind;
  _SettingsSection _section = _SettingsSection.about;
  var _transferActive = false;

  Future<void> _importCanvas() async {
    final callback = widget.onImportCanvas;
    if (_transferActive || callback == null) return;
    setState(() => _transferActive = true);
    try {
      final imported = await callback();
      if (!mounted) return;
      if (imported) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _transferActive = false);
    }
  }

  Future<void> _exportCanvas() async {
    final callback = widget.onExportCanvas;
    if (_transferActive || callback == null) return;
    setState(() => _transferActive = true);
    try {
      await callback();
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _transferActive = false);
    }
  }

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
                      selected: _section == _SettingsSection.about,
                      selectedColor: colors.accent,
                      selectedTileColor: colors.accentSoft,
                      hoverColor: colors.surfaceHover,
                      focusColor: colors.focusRing,
                      leading: const Icon(Icons.info_outline, size: 20),
                      title: const Text('About'),
                      onTap: () => setState(
                        () => _section = _SettingsSection.about,
                      ),
                    ),
                    ListTile(
                      selected: _section == _SettingsSection.canvas,
                      selectedColor: colors.accent,
                      selectedTileColor: colors.accentSoft,
                      hoverColor: colors.surfaceHover,
                      focusColor: colors.focusRing,
                      leading: const Icon(Icons.grid_view, size: 20),
                      title: const Text('Canvas'),
                      onTap: () => setState(
                        () => _section = _SettingsSection.canvas,
                      ),
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
                          _section == _SettingsSection.about
                              ? 'About'
                              : 'Canvas',
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
                    if (_section == _SettingsSection.about)
                      Text(
                        'beyond - dev build',
                        style: typo.body.copyWith(color: colors.textSecondary),
                      )
                    else ...[
                      Text(
                        'Background',
                        style: typo.label.copyWith(color: colors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Select<CanvasBackgroundKind>(
                        key: const ValueKey('canvas-background-select'),
                        value: _canvasBackgroundKind,
                        options: const [
                          SelectOption(
                            value: CanvasBackgroundKind.dotGrid,
                            label: 'Dot grid',
                          ),
                          SelectOption(
                            value: CanvasBackgroundKind.plain,
                            label: 'Plain',
                          ),
                        ],
                        onChanged: (kind) {
                          setState(() => _canvasBackgroundKind = kind);
                          widget.onCanvasBackgroundChanged?.call(kind);
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Data',
                        style: typo.label.copyWith(color: colors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Button(
                              key: const ValueKey('canvas-import-button'),
                              onPressed:
                                  _transferActive ||
                                      widget.onImportCanvas == null
                                  ? null
                                  : _importCanvas,
                              variant: ButtonVariant.outline,
                              child: const Text('Import canvas'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Button(
                              key: const ValueKey('canvas-export-button'),
                              onPressed:
                                  _transferActive ||
                                      widget.onExportCanvas == null
                                  ? null
                                  : _exportCanvas,
                              child: const Text('Export canvas'),
                            ),
                          ),
                        ],
                      ),
                    ],
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
