// Previews every app-wide Beyond UI widget and semantic theme token.
// Discovered only by Flutter's local widget preview environment.

import 'package:beyond/theme/starless.dart';
import 'package:beyond/ui/common/b_container.dart';
import 'package:beyond/ui/common/b_icon_button.dart';
import 'package:beyond/ui/common/b_icon_drag.dart';
import 'package:beyond/ui/common/color_picker.dart';
import 'package:beyond/ui/common/context_menu.dart';
import 'package:beyond/ui/common/discrete_slider.dart';
import 'package:beyond/ui/common/select.dart';
import 'package:beyond/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:scroll_animator/scroll_animator.dart';

// ---------- Preview ----------

PreviewThemeData devPreviewTheme() {
  return PreviewThemeData(materialLight: starlessLightThemeData);
}

@Preview(
  name: 'Beyond UI',
  size: Size(1100, 900),
  theme: devPreviewTheme,
  brightness: Brightness.light,
)
Widget devUiPreview() => const _DevUiPreview();

class _DevUiPreview extends StatefulWidget {
  const _DevUiPreview();

  @override
  State<_DevUiPreview> createState() => _DevUiPreviewState();
}

class _DevUiPreviewState extends State<_DevUiPreview> {
  final _scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );
  var _color = const Color(0xff3b82f6);
  var _slider = 2.25;
  var _select = 'Canvas';
  var _searchableSelect = 'Dart';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return ColoredBox(
      color: theme.colors.canvasBackground,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Beyond UI', style: theme.typo.display),
                const SizedBox(height: 32),
                _section(theme, 'Colors', _colors(theme)),
                _section(theme, 'Typography', _typography(theme)),
                _section(theme, 'Containers', _containers()),
                _section(theme, 'Icon controls', _iconControls()),
                _section(
                  theme,
                  'Color picker',
                  ColorPickerWidget(
                    color: _color,
                    onChanged: (color) => setState(() => _color = color),
                  ),
                ),
                _section(theme, 'Context menu', _contextMenu(theme)),
                _section(
                  theme,
                  'Discrete slider',
                  SizedBox(
                    width: 320,
                    child: DiscreteSlider(
                      value: _slider,
                      onChanged: (value) => setState(() => _slider = value),
                    ),
                  ),
                ),
                _section(theme, 'Selects', _selects()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(BTheme theme, String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.typo.heading),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _colors(BTheme theme) {
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
      ('Border', colors.border),
      ('Border subtle', colors.borderSubtle),
      ('Accent', colors.accent),
      ('Accent hover', colors.accentHover),
      ('Accent pressed', colors.accentPressed),
      ('Accent soft', colors.accentSoft),
      ('Accent subtle', colors.accentSubtle),
      ('Focus', colors.focusRing),
      ('Shadow', colors.shadow),
      ('Scrim', colors.scrim),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (label, color) in swatches)
          SizedBox(
            width: 108,
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
                  _hex(color),
                  style: theme.typo.code.copyWith(
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

  String _hex(Color color) {
    final argb = color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return argb.startsWith('FF') ? '#${argb.substring(2)}' : '#$argb';
  }

  Widget _typography(BTheme theme) {
    final typography = [
      ('Display', theme.typo.display),
      ('Heading', theme.typo.heading),
      ('Title', theme.typo.title),
      ('Body', theme.typo.body),
      ('Label', theme.typo.label),
      ('Code', theme.typo.code),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, style) in typography) ...[
          Text('$label · The quick brown fox jumps over the lazy dog', style: style),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _containers() {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        BContainer(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Default'),
          ),
        ),
        BContainer(
          selected: true,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Selected'),
          ),
        ),
      ],
    );
  }

  Widget _iconControls() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        BIconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add',
          onPressed: () {},
        ),
        BIconButton(
          icon: const Icon(Icons.check),
          tooltip: 'Select',
          selectedTooltip: 'Selected',
          selected: true,
          onPressed: () {},
        ),
        BIconDrag(
          icon: const Icon(Icons.open_with),
          tooltip: 'Drag',
          onDragStart: (_) => null,
        ),
      ],
    );
  }

  Widget _contextMenu(BTheme theme) {
    return BContextMenu(
      semanticLabel: 'Context menu preview',
      groups: [
        [
          BContextMenuAction(
            label: 'Duplicate',
            icon: Icons.copy_outlined,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyD,
              control: true,
            ),
            onPressed: () {},
          ),
          const BContextMenuAction(
            label: 'Unavailable',
            icon: Icons.block,
            onPressed: null,
          ),
        ],
        [
          BContextMenuAction(
            label: 'Delete',
            icon: Icons.delete_outline,
            destructive: true,
            onPressed: () {},
          ),
        ],
      ],
      child: Container(
        width: 320,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colors.surface,
          borderRadius: theme.geo.radiusMedium,
          border: Border.all(color: theme.colors.borderSubtle),
        ),
        child: Text('Click or right-click', style: theme.typo.body),
      ),
    );
  }

  Widget _selects() {
    const options = [
      SelectOption(value: 'Canvas', label: 'Canvas'),
      SelectOption(value: 'Dart', label: 'Dart'),
      SelectOption(value: 'Markdown', label: 'Markdown'),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        Select<String>(
          value: _select,
          options: options,
          onChanged: (value) => setState(() => _select = value),
        ),
        SearchableSelect<String>(
          value: _searchableSelect,
          options: options,
          preferredValues: const ['Dart'],
          searchHint: 'Search formats',
          onChanged: (value) => setState(() => _searchableSelect = value),
        ),
      ],
    );
  }
}
