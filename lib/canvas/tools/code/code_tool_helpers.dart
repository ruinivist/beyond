// Provides the code tool's draggable language-selection header.
// Used internally by the code tool rendering flow.

part of 'code_tool.dart';

// ---------- Header ----------

class _CodeBlockHeader extends StatelessWidget {
  const _CodeBlockHeader({
    required this.model,
    required this.onMove,
    required this.onChangeBoundary,
  });

  final CodeBlockModel model;
  final ValueChanged<Offset> onMove;
  final VoidCallback onChangeBoundary;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    return SizedBox(
      height: BSizes.defaultIconButtonSize.height,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: RawGestureDetector(
          key: const ValueKey('code-block-header'),
          behavior: HitTestBehavior.opaque,
          gestures: {
            ImmediateMultiDragGestureRecognizer: immediateDragGestureFactory((_) => CallbackDrag(onMove)),
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.code, size: BSizes.defaultIconSize, color: colors.textMuted),
                const SizedBox(width: 8),
                SearchableSelect<CodeLanguage>(
                  value: model.language,
                  preferredValues: CodeLanguage.values,
                  searchHint: 'Search languages…',
                  options: [
                    for (final language in CodeLanguage.values) SelectOption(value: language, label: language.label),
                  ],
                  showBorder: false,
                  onChanged: (language) {
                    onChangeBoundary();
                    model.language = language;
                    onChangeBoundary();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
