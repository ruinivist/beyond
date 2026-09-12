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
      height: 40,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: RawGestureDetector(
          key: const ValueKey('code-block-header'),
          behavior: HitTestBehavior.opaque,
          gestures: {
            ImmediateMultiDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
                  ImmediateMultiDragGestureRecognizer.new,
                  (recognizer) {
                    recognizer.onStart = (_) => _CodeBlockDrag(onMove);
                  },
                ),
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.code, size: 18, color: colors.textMuted),
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

// ---------- Gestures ----------

class _CodeBlockDrag extends Drag {
  _CodeBlockDrag(this.onMove);

  final ValueChanged<Offset> onMove;

  @override
  void update(DragUpdateDetails details) => onMove(details.delta);
}
