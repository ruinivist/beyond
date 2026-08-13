import 'package:flutter/material.dart';
import 'package:beyond/canvas/canvas_page.dart';
import 'package:beyond/canvas/tools/code_block/code_block.dart';
import 'package:beyond/canvas/tools/markdown/markdown_block.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/foundation/button.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/theme/starless_light.dart';
import 'package:beyond/widgets/settings_dialog.dart';
import 'package:re_editor/re_editor.dart';
import 'package:scroll_animator/scroll_animator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadCodeFont();
  runApp(const WidgetGalleryApp());
}

class WidgetGalleryApp extends StatelessWidget {
  const WidgetGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Beyond widget gallery',
      theme: starlessLightThemeData,
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
  final _scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );
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
    _scrollController.dispose();
    _textModel.dispose();
    _codeModel.dispose();
    _markdownModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final buttonTextStyle = theme.typo.body.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    final sourceSerif = theme.typo.heading;
    final editorialBody = TextStyle(
      fontFamily: sourceSerif.fontFamily,
      fontFamilyFallback: sourceSerif.fontFamilyFallback,
      fontSize: 16,
      height: 1.5,
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colors.surfaceRaised,
        foregroundColor: theme.colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        title: const Text('Beyond widget gallery'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.colors.borderSubtle),
        ),
      ),
      body: SingleChildScrollView(
        key: const ValueKey('gallery-scroll'),
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Starless Light',
                  style: theme.typo.display.copyWith(
                    fontSize: 28,
                    color: theme.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Existing app widgets and proposed core controls, rendered '
                  'against the current theme.',
                  style: theme.typo.body.copyWith(
                    color: theme.colors.textSecondary,
                  ),
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
                      note:
                          'Three semantic families for UI, editorial, and code.',
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
                          Button(
                            key: const ValueKey('open-settings'),
                            textStyle: buttonTextStyle,
                            variant: ButtonVariant.outline,
                            onPressed: _openSettings,
                            leadingIcon: const Icon(Icons.settings_outlined),
                            child: const Text('Open settings'),
                          ),
                          Button(
                            key: const ValueKey('open-canvas'),
                            textStyle: buttonTextStyle,
                            variant: ButtonVariant.outline,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const CanvasPage(),
                              ),
                            ),
                            leadingIcon: const Icon(Icons.open_in_full),
                            child: const Text('Open canvas'),
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
                          'Primary, outline, secondary, quiet, destructive, '
                          'link, icon, and disabled actions.',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Button(
                            textStyle: buttonTextStyle,
                            onPressed: () {},
                            child: const Text('Primary'),
                          ),
                          Button(
                            textStyle: buttonTextStyle,
                            variant: ButtonVariant.outline,
                            onPressed: () {},
                            child: const Text('Secondary'),
                          ),
                          Button(
                            textStyle: buttonTextStyle,
                            variant: ButtonVariant.secondary,
                            onPressed: () {},
                            child: const Text('Secondary fill'),
                          ),
                          Tooltip(
                            message: 'Favorite',
                            child: Button(
                              textStyle: buttonTextStyle,
                              variant: ButtonVariant.ghost,
                              size: ButtonSize.icon,
                              onPressed: () {},
                              leadingIcon: const Icon(Icons.favorite_outline),
                            ),
                          ),
                          Button(
                            textStyle: buttonTextStyle,
                            variant: ButtonVariant.ghost,
                            onPressed: () {},
                            child: const Text('Quiet'),
                          ),
                          Button(
                            textStyle: buttonTextStyle,
                            variant: ButtonVariant.destructive,
                            onPressed: () {},
                            child: const Text('Destructive'),
                          ),
                          Button(
                            textStyle: buttonTextStyle,
                            variant: ButtonVariant.link,
                            onPressed: () {},
                            child: const Text('Link'),
                          ),
                          Button(
                            textStyle: buttonTextStyle,
                            onPressed: null,
                            child: const Text('Disabled'),
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
                      child: Select<String>(
                        key: const ValueKey('gallery-dropdown'),
                        value: _dropdownValue,
                        options: const [
                          SelectOption(value: 'Canvas', label: 'Canvas'),
                          SelectOption(value: 'Code', label: 'Code'),
                          SelectOption(value: 'Markdown', label: 'Markdown'),
                        ],
                        onChanged: (value) =>
                            setState(() => _dropdownValue = value),
                        textStyle: theme.typo.body.copyWith(fontSize: 14),
                        iconColor: theme.colors.textSecondary,
                        borderRadius: BorderRadius.circular(8),
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
                        color: theme.colors.surface,
                        borderRadius: BorderRadius.circular(10),
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
                                child: Button(
                                  textStyle: buttonTextStyle,
                                  variant: ButtonVariant.outline,
                                  onPressed: () {},
                                  child: const Text('Hover for tooltip'),
                                ),
                              ),
                              Button(
                                textStyle: buttonTextStyle,
                                variant: ButtonVariant.outline,
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
                            Text(
                              'Nothing here yet',
                              style: editorialBody.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add a block to start this canvas.',
                              style: editorialBody.copyWith(
                                color: theme.colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Button(
                              textStyle: buttonTextStyle,
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
                      child: Button(
                        textStyle: buttonTextStyle,
                        variant: ButtonVariant.outline,
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
    final colors = BTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: BTheme.of(
              context,
            ).typo.heading.copyWith(fontSize: 20, color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: BTheme.of(
              context,
            ).typo.body.copyWith(color: colors.textSecondary),
          ),
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

  Widget _colorSwatches(BColors colors) {
    final swatches = [
      ('Canvas', starlessCanvasBackground),
      ('Grid', starlessCanvasGrid),
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
                Text(
                  label,
                  style: BTheme.of(context).typo.body.copyWith(fontSize: 12),
                ),
                Text(
                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  style: BTheme.of(
                    context,
                  ).typo.body.copyWith(color: colors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _typography(BuildContext context) {
    final typography = BTheme.of(context).typo;
    final colors = BTheme.of(context).colors;
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
          'IBM Plex Mono · code and technical metadata',
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

  Widget _surfaceStates(BTheme theme) {
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
              style: theme.typo.body.copyWith(
                fontSize: 12,
                color: label == 'Disabled'
                    ? colors.textMuted
                    : colors.textPrimary,
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
    BTheme theme, {
    required String label,
    String? hint,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
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

  void _openSettings() {
    showDialog<void>(
      context: context,
      barrierColor: BTheme.of(context).colors.scrim,
      builder: (_) => const SettingsDialog(),
    );
  }

  void _openConfirmation() {
    final theme = BTheme.of(context);
    final buttonTextStyle = theme.typo.body.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear the canvas?'),
        content: const Text('This removes every block from the current view.'),
        actions: [
          Button(
            textStyle: buttonTextStyle,
            variant: ButtonVariant.link,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          Button(
            textStyle: buttonTextStyle,
            variant: ButtonVariant.destructive,
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
    final theme = BTheme.of(context);
    return Material(
      color: theme.colors.surfaceRaised,
      elevation: 8,
      shadowColor: theme.colors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
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
                  child: Text(title, style: BTheme.of(context).typo.title),
                ),
                _StatusBadge(existing: existing),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              note,
              style: theme.typo.body.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
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
    final colors = BTheme.of(context).colors;
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
          style: BTheme.of(context).typo.label.copyWith(
            color: existing ? colors.accentPressed : colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
