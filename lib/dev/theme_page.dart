// Provides a compact development reference for Beyond's colors and typography.
// Opened from debug settings while reviewing or adjusting application themes.

import 'package:beyond/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:scroll_animator/scroll_animator.dart';

// ---------- Page ----------

class ThemeDevPage extends StatefulWidget {
  const ThemeDevPage({super.key});

  @override
  State<ThemeDevPage> createState() => _ThemeDevPageState();
}

class _ThemeDevPageState extends State<ThemeDevPage> {
  // ---------- State ----------

  final _scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );

  // ---------- Lifecycle ----------

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colors.canvasBackground,
      appBar: AppBar(
        title: const Text('Theme'),
        backgroundColor: theme.colors.surfaceRaised,
        foregroundColor: theme.colors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        key: const ValueKey('theme-dev-scroll'),
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Colors', style: theme.typo.heading),
                const SizedBox(height: 16),
                _colorSwatches(theme),
                const SizedBox(height: 40),
                Text('Typography', style: theme.typo.heading),
                const SizedBox(height: 16),
                _typography(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Theme previews ----------

  Widget _colorSwatches(BTheme theme) {
    final colors = theme.colors;
    final swatches = [
      ('Canvas', colors.canvasBackground),
      ('Grid', colors.canvasGrid),
      ('Surface', colors.surface),
      ('Raised', colors.surfaceRaised),
      ('Subtle', colors.surfaceSubtle),
      ('Hover', colors.surfaceHover),
      ('Pressed', colors.surfacePressed),
      ('Text', colors.textPrimary),
      ('Secondary', colors.textSecondary),
      ('Muted', colors.textMuted),
      ('Border', colors.borderSubtle),
      ('Accent', colors.accent),
      ('Accent hover', colors.accentHover),
      ('Accent pressed', colors.accentPressed),
      ('Accent soft', colors.accentSoft),
      ('Accent subtle', colors.accentSubtle),
      ('Focus', colors.focusRing),
      ('Scrim', colors.scrim),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (label, color) in swatches)
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: theme.geo.radiusMedium,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                ),
                const SizedBox(height: 4),
                Text(label, style: theme.typo.body.copyWith(fontSize: 12)),
                Text(
                  '#${_colorHex(color)}',
                  style: theme.typo.body.copyWith(
                    color: colors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _colorHex(Color color) => color.toARGB32().toRadixString(16).substring(2).toUpperCase();

  Widget _typography(BTheme theme) {
    final typography = theme.typo;
    final colors = theme.colors;
    final sourceSerif = typography.heading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Roboto Mono · UI and chrome',
          style: typography.title.copyWith(color: colors.textPrimary),
        ),
        Text(
          'Controls, navigation, labels · 11–14 px · 400–600',
          style: typography.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
        Text(
          'Source Serif 4 · editorial and document',
          style: sourceSerif.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: colors.textPrimary,
          ),
        ),
        Text(
          'A heading for a note or rendered Markdown.',
          style: sourceSerif.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: colors.textPrimary,
          ),
        ),
        Text(
          'Long-form prose and large canvas text use this warmer reading face.',
          style: sourceSerif.copyWith(
            fontSize: 16,
            height: 1.5,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'JetBrains Mono · code and technical metadata',
          style: typography.code.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'const line = 42;',
          style: typography.code.copyWith(color: colors.textPrimary),
        ),
        Text(
          'MARKDOWN · 0.1.0',
          style: typography.code.copyWith(
            color: colors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
