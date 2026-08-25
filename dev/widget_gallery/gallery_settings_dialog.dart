import 'dart:math' as math;

import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';

class GallerySettingsDialog extends StatefulWidget {
  const GallerySettingsDialog({super.key});

  @override
  State<GallerySettingsDialog> createState() => _GallerySettingsDialogState();
}

enum _GallerySettingsSection { about, canvas }

class _GallerySettingsDialogState extends State<GallerySettingsDialog> {
  _GallerySettingsSection _section = _GallerySettingsSection.canvas;
  CanvasBackgroundKind _backgroundKind = CanvasBackgroundKind.dotGrid;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final viewport = MediaQuery.sizeOf(context);
    final width = math.min(560, math.max(0, viewport.width - 32)).toDouble();
    final height = math.min(360, math.max(0, viewport.height - 32)).toDouble();

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
            Positioned(top: 24, right: 24, child: _closeButton(context)),
          ],
        ),
      ),
    );
  }

  Widget _closeButton(BuildContext context) {
    final theme = BTheme.of(context);
    return IconButton(
      key: const ValueKey('gallery-settings-close'),
      tooltip: 'Close settings',
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
            padding: const EdgeInsets.all(24),
          ),
        ),
        _divider(theme),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
          padding: const EdgeInsets.all(24),
          horizontal: horizontalNavigation,
        );
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              navigation,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(
                  height: 25,
                  color: theme.colors.borderSubtle.withValues(alpha: 0.55),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
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
        section: _GallerySettingsSection.about,
        icon: Icons.info_outline,
        label: 'About',
      ),
      _navigationItem(
        context,
        section: _GallerySettingsSection.canvas,
        icon: Icons.grid_view,
        label: 'Canvas',
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
    required _GallerySettingsSection section,
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
      _GallerySettingsSection.about => _aboutContent(context),
      _GallerySettingsSection.canvas => _canvasContent(context),
    };
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
          key: const ValueKey('gallery-settings-background-select'),
          value: _backgroundKind,
          options: const [
            SelectOption(
              value: CanvasBackgroundKind.dotGrid,
              label: 'Dot grid',
            ),
            SelectOption(value: CanvasBackgroundKind.plain, label: 'Plain'),
          ],
          showBorder: false,
          onChanged: (kind) => setState(() => _backgroundKind = kind),
        ),
      ],
    );
  }
}
