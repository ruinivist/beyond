import 'dart:math' as math;

import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/foundation/button.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/theme/starless.dart';
import 'package:flutter/material.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    this.appTheme = AppTheme.starlessLight,
    this.canvasBackgroundKind = CanvasBackgroundKind.dotGrid,
    this.noIcons = false,
    this.onAppThemeChanged,
    this.onCanvasBackgroundChanged,
    this.onNoIconsChanged,
    this.onImportCanvas,
    this.onExportCanvas,
    super.key,
  });

  final AppTheme appTheme;
  final CanvasBackgroundKind canvasBackgroundKind;
  final bool noIcons;
  final ValueChanged<AppTheme>? onAppThemeChanged;
  final ValueChanged<CanvasBackgroundKind>? onCanvasBackgroundChanged;
  final ValueChanged<bool>? onNoIconsChanged;
  final Future<bool> Function()? onImportCanvas;
  final Future<void> Function()? onExportCanvas;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

enum _SettingsSection { about, canvas, interface }

class _SettingsDialogState extends State<SettingsDialog> {
  _SettingsSection _section = _SettingsSection.canvas;
  late AppTheme _appTheme = widget.appTheme;
  late CanvasBackgroundKind _canvasBackgroundKind = widget.canvasBackgroundKind;
  late bool _noIcons = widget.noIcons;
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
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final viewport = MediaQuery.sizeOf(context);
    final width = math.min(840, math.max(0, viewport.width - 32)).toDouble();
    final height = math.min(540, math.max(0, viewport.height - 32)).toDouble();

    return Dialog(
      backgroundColor: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: theme.geo.elevationMedium,
      shadowColor: colors.shadow,
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: theme.geo.radiusLarge),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 520
                  ? _compactBody(context)
                  : _wideBody(context),
            ),
            Positioned(top: 16, right: 16, child: _closeButton(context)),
          ],
        ),
      ),
    );
  }

  Widget _closeButton(BuildContext context) {
    final theme = BTheme.of(context);
    return IconButton(
      key: const ValueKey('settings-close'),
      tooltip: 'Close',
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.close),
      iconSize: 20,
      color: theme.colors.textSecondary,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return theme.colors.surfacePressed;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return theme.colors.surfaceHover;
          }
          return Colors.transparent;
        }),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? BorderSide(color: theme.colors.focusRing)
              : BorderSide.none,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: theme.geo.radiusSmall),
        ),
      ),
    );
  }

  Widget _wideBody(BuildContext context) {
    final theme = BTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 152,
          child: _navigation(
            context,
            padding: const EdgeInsets.all(16),
          ),
        ),
        _divider(theme),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _sectionContent(context),
          ),
        ),
      ],
    );
  }

  Widget _compactBody(BuildContext context) {
    final theme = BTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalNavigation = constraints.maxWidth >= 340;
        final navigation = _navigation(
          context,
          padding: const EdgeInsets.all(16),
          horizontal: horizontalNavigation,
        );
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              navigation,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 25,
                  color: theme.colors.borderSubtle.withValues(alpha: 0.55),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _sectionContent(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navigation(
    BuildContext context, {
    required EdgeInsets padding,
    bool horizontal = false,
  }) {
    final children = [
      _navigationItem(
        context,
        section: _SettingsSection.interface,
        icon: Icons.tune,
        label: 'Interface',
      ),
      _navigationItem(
        context,
        section: _SettingsSection.canvas,
        icon: Icons.grid_view,
        label: 'Canvas',
      ),
      _navigationItem(
        context,
        section: _SettingsSection.about,
        icon: Icons.info_outline,
        label: 'About',
      ),
    ];

    return Padding(
      padding: padding,
      child: horizontal
          ? Row(
              children: [
                for (final child in children) Expanded(child: child),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
    );
  }

  Widget _navigationItem(
    BuildContext context, {
    required _SettingsSection section,
    required IconData icon,
    required String label,
  }) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final selected = _section == section;
    final foreground = selected ? colors.accent : colors.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? colors.accentSoft : Colors.transparent,
        borderRadius: theme.geo.radiusSmall,
        child: InkWell(
          borderRadius: theme.geo.radiusSmall,
          hoverColor: colors.surfaceHover,
          focusColor: colors.surfaceHover,
          splashColor: colors.surfacePressed,
          onTap: () => setState(() => _section = section),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.typo.body.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(BTheme theme) {
    return SizedBox(
      width: 1,
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          child: SizedBox(
            width: 1,
            height: constraints.maxHeight * 0.75,
            child: ColoredBox(
              color: theme.colors.borderSubtle.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionContent(BuildContext context) {
    return switch (_section) {
      _SettingsSection.about => _aboutContent(context),
      _SettingsSection.canvas => _canvasContent(context),
      _SettingsSection.interface => _interfaceContent(context),
    };
  }

  Widget _interfaceContent(BuildContext context) {
    final theme = BTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme',
            style: theme.typo.label.copyWith(color: theme.colors.textPrimary),
          ),
          const SizedBox(height: 10),
          Select<AppTheme>(
            key: const ValueKey('theme-select'),
            value: _appTheme,
            options: [
              for (final appTheme in AppTheme.values)
                SelectOption(value: appTheme, label: appTheme.label),
            ],
            showBorder: false,
            onChanged: widget.onAppThemeChanged == null
                ? null
                : (appTheme) {
                    setState(() => _appTheme = appTheme);
                    widget.onAppThemeChanged!(appTheme);
                  },
          ),
          const SizedBox(height: 20),
          MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'No icons',
                    style: theme.typo.body.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                ),
                Switch(
                  key: const ValueKey('no-icons-switch'),
                  value: _noIcons,
                  onChanged: (value) {
                    setState(() => _noIcons = value);
                    widget.onNoIconsChanged?.call(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutContent(BuildContext context) {
    final theme = BTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'beyond - dev build',
          style: theme.typo.body.copyWith(color: theme.colors.textSecondary),
        ),
      ],
    );
  }

  Widget _canvasContent(BuildContext context) {
    final theme = BTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Background',
          style: theme.typo.label.copyWith(color: theme.colors.textPrimary),
        ),
        const SizedBox(height: 10),
        Select<CanvasBackgroundKind>(
          key: const ValueKey('canvas-background-select'),
          value: _canvasBackgroundKind,
          options: const [
            SelectOption(
              value: CanvasBackgroundKind.dotGrid,
              label: 'Dot grid',
            ),
            SelectOption(value: CanvasBackgroundKind.plain, label: 'Plain'),
          ],
          showBorder: false,
          onChanged: (kind) {
            setState(() => _canvasBackgroundKind = kind);
            widget.onCanvasBackgroundChanged?.call(kind);
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Data',
          style: theme.typo.label.copyWith(color: theme.colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Button(
              key: const ValueKey('canvas-import-button'),
              onPressed: _transferActive || widget.onImportCanvas == null
                  ? null
                  : _importCanvas,
              variant: ButtonVariant.secondary,
              child: const Text('Import canvas'),
            ),
            Button(
              key: const ValueKey('canvas-export-button'),
              onPressed: _transferActive || widget.onExportCanvas == null
                  ? null
                  : _exportCanvas,
              variant: ButtonVariant.secondary,
              child: const Text('Export canvas'),
            ),
          ],
        ),
      ],
    );
  }
}
