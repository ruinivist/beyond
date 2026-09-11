// Provides a development gallery for Beyond's reusable widgets and themes.
// Used manually to inspect component states outside the canvas editor.

import 'dart:async';

import 'package:beyond/canvas/attachments/store.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_page.dart';
import 'package:beyond/canvas/tools/code_block/code_block.dart';
import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/foundation/button.dart';
import 'package:beyond/foundation/context_menu.dart';
import 'package:beyond/foundation/discrete_slider.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/theme/starless.dart';
import 'package:beyond/widgets/settings_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:scroll_animator/scroll_animator.dart';

// ---------- Gallery bootstrap ----------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) await BrowserContextMenu.disableContextMenu();
  await loadFonts();
  runApp(const WidgetGalleryApp());
}

// ---------- Application ----------

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

// ---------- Gallery page ----------

/// Displays reusable components, semantic tokens, and interaction states.
/// Used by developers for manual visual inspection during component work.
class WidgetGalleryPage extends StatefulWidget {
  const WidgetGalleryPage({super.key});

  @override
  State<WidgetGalleryPage> createState() => _WidgetGalleryPageState();
}

class _WidgetGalleryPageState extends State<WidgetGalleryPage> {
  // ---------- State ----------

  final AttachmentStore _attachmentStore = createAttachmentStore();
  final _scrollController = AnimatedScrollController(
    animationFactory: const ChromiumEaseInOut(),
  );
  final _textModel = TextBlockModel(
    TextElementData(
      id: 'gallery-text',
      position: Offset.zero,
      width: textNodeDefaultWidth,
      height: null,
      markdown: '',
      style: const TextNodeStyle(
        fontFamily: 'Source Serif 4',
        fontSize: textNodeDefaultFontSize,
        color: '#201C1A',
      ),
    ),
  );
  final _codeModel = CodeBlockModel(
    CodeElementData(
      id: 'gallery-code',
      position: Offset.zero,
      size: const Size(520, 320),
      language: CodeLanguage.dart,
      source: '',
    ),
  );
  var _dropdownValue = 'Canvas';
  var _searchableLanguage = 'Dart';
  var _checked = true;
  var _choice = 0;
  var _snapValue = 2.25;
  var _chip = 0;
  var _segment = 0;

  // ---------- Lifecycle ----------

  @override
  void initState() {
    super.initState();
    _textModel.controller.text = 'A real editable text block';
    _codeModel
      ..selected = true
      ..controller.codeLines = CodeLines.fromText(
        "void main() {\n  print('Hello, canvas!');\n}",
      );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textModel.dispose();
    _codeModel.dispose();
    super.dispose();
  }

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
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
                  description: 'Theme surfaces and interaction states.',
                  cards: [
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
                          attachmentStore: _attachmentStore,
                          onEdit: () {
                            setState(() => _textModel.editing = true);
                            _textModel.focusNode.requestFocus();
                          },
                          onMove: (_) {},
                          onResize: (_, _) {},
                        ),
                      ),
                    ),
                    _GalleryCard(
                      title: 'Text settings',
                      existing: true,
                      note:
                          'The production control reveals font and preset '
                          'color controls to its right.',
                      child: TextSettings(
                        model: _textModel,
                        onChangeBoundary: () {},
                      ),
                    ),
                    _GalleryCard(
                      title: 'Code block',
                      existing: true,
                      note: 'Resizable editor with syntax and language controls.',
                      child: _horizontalPreview(
                        CodeBlock(
                          model: _codeModel,
                          onMove: (_) {},
                          onChangeBoundary: () {},
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
                          BButton(
                            key: const ValueKey('open-settings'),
                            variant: ButtonVariant.outline,
                            onPressed: _openSettings,
                            leadingIcon: const Icon(Icons.settings_outlined),
                            child: const Text('Open settings'),
                          ),
                          BButton(
                            key: const ValueKey('open-canvas'),
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
                          BButton(
                            onPressed: () {},
                            child: const Text('Primary'),
                          ),
                          BButton(
                            variant: ButtonVariant.outline,
                            onPressed: () {},
                            child: const Text('Secondary'),
                          ),
                          BButton(
                            variant: ButtonVariant.secondary,
                            onPressed: () {},
                            child: const Text('Secondary fill'),
                          ),
                          Tooltip(
                            message: 'Favorite',
                            child: BButton(
                              variant: ButtonVariant.ghost,
                              size: ButtonSize.icon,
                              onPressed: () {},
                              leadingIcon: const Icon(Icons.favorite_outline),
                            ),
                          ),
                          BButton(
                            variant: ButtonVariant.ghost,
                            onPressed: () {},
                            child: const Text('Quiet'),
                          ),
                          BButton(
                            variant: ButtonVariant.destructive,
                            onPressed: () {},
                            child: const Text('Destructive'),
                          ),
                          BButton(
                            variant: ButtonVariant.link,
                            onPressed: () {},
                            child: const Text('Link'),
                          ),
                          const BButton(
                            onPressed: null,
                            child: Text('Disabled'),
                          ),
                        ],
                      ),
                    ),
                    _GalleryCard(
                      title: 'Text inputs',
                      existing: false,
                      note: 'Single-line, multiline, and disabled entry states.',
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
                        onChanged: (value) => setState(() => _dropdownValue = value),
                      ),
                    ),
                    _GalleryCard(
                      title: 'Searchable select',
                      existing: false,
                      note:
                          'Search a longer language list with common choices '
                          'first.',
                      child: SearchableSelect<String>(
                        key: const ValueKey('gallery-searchable-select'),
                        value: _searchableLanguage,
                        preferredValues: const [
                          'Python',
                          'TypeScript',
                          'Dart',
                          'JavaScript',
                          'Go',
                          'Rust',
                        ],
                        searchHint: 'Search languages…',
                        options: const [
                          SelectOption(value: 'C', label: 'C'),
                          SelectOption(value: 'C++', label: 'C++'),
                          SelectOption(value: 'Dart', label: 'Dart'),
                          SelectOption(value: 'Go', label: 'Go'),
                          SelectOption(value: 'Java', label: 'Java'),
                          SelectOption(
                            value: 'JavaScript',
                            label: 'JavaScript',
                          ),
                          SelectOption(value: 'Python', label: 'Python'),
                          SelectOption(value: 'Rust', label: 'Rust'),
                          SelectOption(
                            value: 'TypeScript',
                            label: 'TypeScript',
                          ),
                        ],
                        onChanged: (value) => setState(() => _searchableLanguage = value),
                      ),
                    ),
                    _GalleryCard(
                      title: 'Context menu',
                      existing: false,
                      note:
                          'Secondary-click the preview to open actions '
                          'at the pointer.',
                      child: _contextMenuPreview(context),
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
                      note: 'Boolean and exclusive value controls.',
                      child: Column(
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Show grid'),
                            value: _checked,
                            activeColor: theme.colors.accent,
                            onChanged: (value) => setState(() => _checked = value ?? false),
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
                        ],
                      ),
                    ),
                    _GalleryCard(
                      title: 'Slider',
                      existing: false,
                      note: 'Choose a discrete width.',
                      child: DiscreteSlider(
                        key: const ValueKey('gallery-discrete-slider'),
                        value: _snapValue,
                        onChanged: (value) => setState(() => _snapValue = value),
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
                                  onSelected: (_) => setState(() => _chip = index),
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
                            onSelectionChanged: (value) => setState(() => _segment = value.first),
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
                        borderRadius: theme.geo.radiusLarge,
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
                  description: 'Transient feedback, progress, and empty states.',
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
                                child: BButton(
                                  variant: ButtonVariant.outline,
                                  onPressed: () {},
                                  child: const Text('Hover for tooltip'),
                                ),
                              ),
                              BButton(
                                variant: ButtonVariant.outline,
                                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
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
                            BButton(
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
                      child: BButton(
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
              final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
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

  // ---------- Preview helpers ----------

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
              borderRadius: theme.geo.radiusMedium,
              border: Border.all(
                color: label == 'Selected' ? colors.accent : colors.borderSubtle,
              ),
              boxShadow: label == 'Raised' ? [BoxShadow(color: colors.shadow, blurRadius: 8)] : null,
            ),
            child: Text(
              label,
              style: theme.typo.body.copyWith(
                fontSize: 12,
                color: label == 'Disabled' ? colors.textMuted : colors.textPrimary,
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

  Widget _contextMenuPreview(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    return BContextMenu(
      semanticLabel: 'Context menu target',
      semanticHint: 'Right-click for actions',
      groups: [
        [
          BContextMenuAction(
            label: 'Open in new tab',
            icon: Icons.open_in_new,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.enter,
              control: true,
            ),
            autofocus: true,
            onPressed: () {},
          ),
          BContextMenuAction(
            label: 'Duplicate',
            icon: Icons.copy_outlined,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyD,
              control: true,
            ),
            onPressed: () {},
          ),
        ],
        [
          BContextMenuAction(
            label: 'Rename',
            icon: Icons.edit_outlined,
            shortcut: const SingleActivator(LogicalKeyboardKey.f2),
            onPressed: () {},
          ),
          const BContextMenuAction(
            label: 'Share',
            icon: Icons.ios_share_outlined,
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyS,
              control: true,
              shift: true,
            ),
            onPressed: null,
          ),
        ],
        [
          BContextMenuAction(
            label: 'Delete',
            icon: Icons.delete_outline,
            shortcut: const SingleActivator(
              LogicalKeyboardKey.delete,
              shift: true,
            ),
            destructive: true,
            onPressed: () {},
          ),
        ],
      ],
      child: SizedBox(
        width: double.infinity,
        height: 144,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: theme.geo.radiusMedium,
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ads_click, size: 28, color: colors.accent),
              const SizedBox(height: 10),
              Text(
                'Right-click this area',
                style: theme.typo.title.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Use arrow keys and Enter in the menu',
                style: theme.typo.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Dialog actions ----------

  InputDecoration _inputDecoration(
    BTheme theme, {
    required String label,
    String? hint,
  }) {
    final border = OutlineInputBorder(
      borderRadius: theme.geo.radiusMedium,
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
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: BTheme.of(context).colors.scrim,
        builder: (_) => const SettingsDialog(),
      ),
    );
  }

  void _openConfirmation() {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Clear the canvas?'),
          content: const Text(
            'This removes every block from the current view.',
          ),
          actions: [
            BButton(
              variant: ButtonVariant.link,
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            BButton(
              variant: ButtonVariant.destructive,
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Supporting widgets ----------

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
      elevation: theme.geo.elevationMedium,
      shadowColor: theme.colors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: theme.geo.radiusLarge,
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
