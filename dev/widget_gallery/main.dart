import 'package:flutter/material.dart';
import 'package:plane/canvas/canvas_page.dart';
import 'package:plane/canvas/tools/code_block/code_block.dart';
import 'package:plane/canvas/tools/markdown/markdown_block.dart';
import 'package:plane/canvas/tools/text/text_block.dart';
import 'package:plane/theme/app_theme.dart';
import 'package:plane/widgets/settings_dialog.dart';
import 'package:re_editor/re_editor.dart';

void main() => runApp(const WidgetGalleryApp());

final _galleryTheme = starlessLightThemeData.copyWith(
  colorScheme: ColorScheme.light(
    primary: starlessLight.colors.accent,
    onPrimary: starlessLight.colors.surface,
    primaryContainer: starlessLight.colors.accentSoft,
    onPrimaryContainer: starlessLight.colors.accentPressed,
    secondary: starlessLight.colors.textSecondary,
    onSecondary: starlessLight.colors.surface,
    secondaryContainer: starlessLight.colors.surfaceSubtle,
    onSecondaryContainer: starlessLight.colors.textPrimary,
    surface: starlessLight.colors.surface,
    onSurface: starlessLight.colors.textPrimary,
    outline: starlessLight.colors.borderSubtle,
    outlineVariant: starlessLight.colors.borderSubtle,
  ),
);

class WidgetGalleryApp extends StatelessWidget {
  const WidgetGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plane widget gallery',
      theme: _galleryTheme,
      home: const WidgetGalleryPage(),
    );
  }
}

class WidgetGalleryPage extends StatefulWidget {
  const WidgetGalleryPage({super.key});

  @override
  State<WidgetGalleryPage> createState() => _WidgetGalleryPageState();
}

class _WidgetGalleryPageState extends State<WidgetGalleryPage> {
  final _textModel = TextBlockModel();
  final _codeModel = CodeBlockModel(const Size(520, 320));
  final _markdownModel = MarkdownBlockModel(const Size(500, 320));
  var _dropdownValue = 'Canvas';
  var _checked = true;
  var _choice = 0;
  var _switched = false;
  var _slider = 0.62;
  var _chip = 0;
  var _segment = 0;

  @override
  void initState() {
    super.initState();
    _textModel.controller.text = 'A real editable text block';
    _codeModel
      ..selected = true
      ..controller.codeLines = CodeLines.fromText(
        "void main() {\n  print('Hello, canvas!');\n}",
      );
    _markdownModel
      ..selected = true
      ..previewing = true
      ..controller.text = '# Markdown\n\nWrite equations like \$E = mc^2\$.';
  }

  @override
  void dispose() {
    _textModel.dispose();
    _codeModel.dispose();
    _markdownModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colors.surfaceRaised,
        foregroundColor: theme.colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        title: const Text('Plane widget gallery'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.colors.borderSubtle),
        ),
      ),
      body: SingleChildScrollView(
        key: const ValueKey('gallery-scroll'),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Starless Light',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: theme.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Existing app widgets and proposed core controls, rendered '
                  'against the current theme.',
                  style: TextStyle(color: theme.colors.textSecondary),
                ),
                const SizedBox(height: 40),
                _section(
                  context,
                  title: 'Foundations',
                  description: 'Theme colors, type, surfaces, and states.',
                  cards: [
                    _GalleryCard(
                      title: 'Semantic colors',
                      existing: true,
                      note: 'Shared meaning for canvas and component styling.',
                      child: _colorSwatches(theme.colors),
                    ),
                    _GalleryCard(
                      title: 'Typography',
                      existing: true,
                      note: 'Current Material type scale with Starless colors.',
                      child: _typography(context),
                    ),
                    _GalleryCard(
                      title: 'Surfaces and states',
                      existing: true,
                      note: 'Raised surfaces and interaction feedback tokens.',
                      child: _surfaceStates(theme),
                    ),
                  ],
                ),
                _section(
                  context,
                  title: 'Canvas components',
                  description: 'Real widgets imported from the production app.',
                  cards: [
                    _GalleryCard(
                      title: 'Text block',
                      existing: true,
                      note: 'Free-form editable text placed on the canvas.',
                      child: _horizontalPreview(
                        TextBlock(
                          model: _textModel,
                          onSelect: (_) {},
                          onMove: (_) {},
                        ),
                      ),
                    ),
                    _GalleryCard(
                      title: 'Code block',
                      existing: true,
                      note:
                          'Resizable editor with syntax and language controls.',
                      child: _horizontalPreview(
                        CodeBlock(
                          model: _codeModel,
                          onSelect: (_) {},
                          onMove: (_) {},
                        ),
                      ),
                    ),
                    _GalleryCard(
                      title: 'Markdown block',
                      existing: true,
                      note: 'Editable Markdown with preview and LaTeX support.',
                      child: _horizontalPreview(
                        MarkdownBlock(
                          model: _markdownModel,
                          onSelect: (_) {},
                          onMove: (_) {},
                        ),
                      ),
                    ),
                    _GalleryCard(
                      title: 'App surfaces',
                      existing: true,
                      note: 'Open exact settings and canvas implementations.',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('open-settings'),
                            onPressed: _openSettings,
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Open settings'),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('open-canvas'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CanvasPage(),
                              ),
                            ),
                            icon: const Icon(Icons.open_in_full),
                            label: const Text('Open canvas'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _section(
                  context,
                  title: 'Actions and inputs',
                  description: 'Gallery-only proposals using existing tokens.',
                  cards: [
                    _GalleryCard(
                      title: 'Buttons',
                      existing: false,
                      note:
                          'Primary, secondary, quiet, icon, and disabled actions.',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton(
                            style: _primaryButtonStyle(theme.colors),
                            onPressed: () {},
                            child: const Text('Primary'),
                          ),
                          OutlinedButton(
                            onPressed: () {},
                            child: const Text('Secondary'),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Quiet'),
                          ),
                          IconButton(
                            tooltip: 'Favorite',
                            onPressed: () {},
                            icon: const Icon(Icons.favorite_outline),
                          ),
                          const FilledButton(
                            onPressed: null,
                            child: Text('Disabled'),
                          ),
                        ],
                      ),
                    ),
                    _GalleryCard(
                      title: 'Text inputs',
                      existing: false,
                      note:
                          'Single-line, multiline, and disabled entry states.',
                      child: Column(
                        children: [
                          TextField(
                            key: const ValueKey('gallery-text-field'),
                            decoration: _inputDecoration(
                              theme,
                              label: 'Title',
                              hint: 'Untitled canvas',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            maxLines: 3,
                            decoration: _inputDecoration(
                              theme,
                              label: 'Description',
                              hint: 'Add a short description',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            enabled: false,
                            decoration: _inputDecoration(
                              theme,
                              label: 'Disabled',
                              hint: 'Unavailable',
                            ),
                          ),
                        ],
                      ),
                    ),
                    _GalleryCard(
                      title: 'Dropdown',
                      existing: false,
                      note: 'Choose one value from a short list.',
                      child: DropdownButtonFormField<String>(
                        key: const ValueKey('gallery-dropdown'),
                        initialValue: _dropdownValue,
                        decoration: _inputDecoration(
                          theme,
                          label: 'Block type',
                        ),
                        dropdownColor:
                            theme.components.codeEditor.dropdownBackground,
                        items: const [
                          DropdownMenuItem(
                            value: 'Canvas',
                            child: Text('Canvas'),
                          ),
                          DropdownMenuItem(value: 'Code', child: Text('Code')),
                          DropdownMenuItem(
                            value: 'Markdown',
                            child: Text('Markdown'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _dropdownValue = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                _section(
                  context,
                  title: 'Selection and navigation',
                  description: 'Interactive choices and compact navigation.',
                  cards: [
                    _GalleryCard(
                      title: 'Selection controls',
                      existing: false,
                      note:
                          'Boolean, exclusive, and continuous value controls.',
                      child: Column(
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Show grid'),
                            value: _checked,
                            activeColor: theme.colors.accent,
                            onChanged: (value) =>
                                setState(() => _checked = value ?? false),
                          ),
                          RadioGroup<int>(
                            groupValue: _choice,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _choice = value);
                              }
                            },
                            child: const Column(
                              children: [
                                RadioListTile<int>(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Select mode'),
                                  value: 0,
                                ),
                                RadioListTile<int>(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Pan mode'),
                                  value: 1,
                                ),
                              ],
                            ),
                          ),
                          SwitchListTile(
                            key: const ValueKey('gallery-switch'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Snap to grid'),
                            value: _switched,
                            activeThumbColor: theme.colors.accent,
                            onChanged: (value) =>
                                setState(() => _switched = value),
                          ),
                          Slider(
                            value: _slider,
                            activeColor: theme.colors.accent,
                            label: '${(_slider * 100).round()}%',
                            onChanged: (value) =>
                                setState(() => _slider = value),
                          ),
                        ],
                      ),
                    ),
                    _GalleryCard(
                      title: 'Chips and segments',
                      existing: false,
                      note: 'Compact filters and two-state view switching.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final (index, label) in [
                                'All',
                                'Recent',
                                'Shared',
                              ].indexed)
                                ChoiceChip(
                                  label: Text(label),
                                  selected: _chip == index,
                                  selectedColor: theme.colors.accentSoft,
                                  onSelected: (_) =>
                                      setState(() => _chip = index),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('Edit')),
                              ButtonSegment(value: 1, label: Text('Preview')),
                            ],
                            selected: {_segment},
                            onSelectionChanged: (value) =>
                                setState(() => _segment = value.first),
                          ),
                        ],
                      ),
                    ),
                    _GalleryCard(
                      title: 'Navigation rows',
                      existing: false,
                      note: 'Settings-style destinations and selected state.',
                      child: Material(
                        color: theme.components.settings.navigationBackground,
                        borderRadius: BorderRadius.circular(
                          theme.components.settings.radius,
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              selected: true,
                              selectedColor: theme.colors.accent,
                              selectedTileColor: theme.colors.accentSoft,
                              leading: const Icon(Icons.dashboard_outlined),
                              title: const Text('Canvas'),
                              onTap: () {},
                            ),
                            ListTile(
                              leading: const Icon(Icons.settings_outlined),
                              title: const Text('Settings'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                _section(
                  context,
                  title: 'Feedback and overlays',
                  description:
                      'Transient feedback, progress, and empty states.',
                  cards: [
                    _GalleryCard(
                      title: 'Feedback',
                      existing: false,
                      note: 'Tooltip, snackbar, and determinate progress.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              Tooltip(
                                message: 'Helpful context',
                                child: OutlinedButton(
                                  onPressed: () {},
                                  child: const Text('Hover for tooltip'),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Canvas saved'),
                                      ),
                                    ),
                                child: const Text('Show snackbar'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          LinearProgressIndicator(
                            value: 0.65,
                            color: theme.colors.accent,
                            backgroundColor: theme.colors.accentSoft,
                          ),
                          const SizedBox(height: 16),
                          CircularProgressIndicator(
                            value: 0.65,
                            color: theme.colors.accent,
                          ),
                        ],
                      ),
                    ),
                    _GalleryCard(
                      title: 'Empty state',
                      existing: false,
                      note: 'A clear next action when no content exists.',
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.space_dashboard_outlined,
                              size: 44,
                              color: theme.colors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Nothing here yet',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add a block to start this canvas.',
                              style: TextStyle(
                                color: theme.colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              style: _primaryButtonStyle(theme.colors),
                              onPressed: () {},
                              child: const Text('Add block'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _GalleryCard(
                      title: 'Confirmation dialog',
                      existing: false,
                      note: 'Confirm an important reversible action.',
                      child: OutlinedButton(
                        onPressed: _openConfirmation,
                        child: const Text('Open confirmation'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required String description,
    required List<Widget> cards,
  }) {
    final colors = context.appTheme.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final card in cards) SizedBox(width: width, child: card),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _colorSwatches(AppSemanticColors colors) {
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
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                ),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12)),
                Text(
                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  style: TextStyle(fontSize: 10, color: colors.textMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _typography(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Display', style: text.displaySmall),
        Text('Headline', style: text.headlineMedium),
        Text('Title', style: text.titleLarge),
        Text('Body text for everyday content.', style: text.bodyLarge),
        Text('Supporting label', style: text.labelMedium),
      ],
    );
  }

  Widget _surfaceStates(AppTheme theme) {
    final colors = theme.colors;
    final states = [
      ('Surface', colors.surface),
      ('Raised', colors.surfaceRaised),
      ('Hover', colors.surfaceHover),
      ('Pressed', colors.surfacePressed),
      ('Selected', colors.accentSoft),
      ('Disabled', colors.surfaceSubtle),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (label, color) in states)
          Container(
            width: 108,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: label == 'Selected'
                    ? colors.accent
                    : colors.borderSubtle,
              ),
              boxShadow: label == 'Raised'
                  ? [BoxShadow(color: colors.shadow, blurRadius: 8)]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: label == 'Disabled'
                    ? colors.textMuted
                    : colors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _horizontalPreview(Widget child) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(padding: const EdgeInsets.all(4), child: child),
    );
  }

  InputDecoration _inputDecoration(
    AppTheme theme, {
    required String label,
    String? hint,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.components.toolbar.radius),
      borderSide: BorderSide(color: theme.colors.borderSubtle),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: theme.colors.surface,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: theme.colors.focusRing, width: 2),
      ),
    );
  }

  ButtonStyle _primaryButtonStyle(AppSemanticColors colors) {
    return FilledButton.styleFrom(
      backgroundColor: colors.accent,
      foregroundColor: colors.surface,
      disabledBackgroundColor: colors.surfacePressed,
      disabledForegroundColor: colors.textMuted,
    );
  }

  void _openSettings() {
    showDialog<void>(
      context: context,
      barrierColor: context.appTheme.components.settings.scrim,
      builder: (_) => const SettingsDialog(),
    );
  }

  void _openConfirmation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear the canvas?'),
        content: const Text('This removes every block from the current view.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: _primaryButtonStyle(context.appTheme.colors),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.title,
    required this.existing,
    required this.note,
    required this.child,
  });

  final String title;
  final bool existing;
  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Material(
      color: theme.colors.surfaceRaised,
      elevation: theme.components.block.elevation,
      shadowColor: theme.colors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.components.block.radius),
        side: BorderSide(color: theme.colors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusBadge(existing: existing),
              ],
            ),
            const SizedBox(height: 4),
            Text(note, style: TextStyle(color: theme.colors.textSecondary)),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.existing});

  final bool existing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appTheme.colors;
    return Semantics(
      label: existing ? 'Existing component' : 'Proposed component',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: existing ? colors.accentSoft : colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: existing ? colors.accentSubtle : colors.borderSubtle,
          ),
        ),
        child: Text(
          existing ? 'Existing' : 'Proposed',
          style: TextStyle(
            color: existing ? colors.accentPressed : colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
