// Provides the code tool's compact title, language, and settings controls.
// Used internally by code rendering and by the active-element settings panel.

part of 'code_tool.dart';

// ---------- Geometry ----------

const _codeTitleHeight = 34.0;
const _codeControlInset = 8.0;
const _codeEditorPadding = 10.0;
const _codeControlAnimationDuration = Duration(milliseconds: 220);

Widget _codeControlTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
      child: child,
    ),
  );
}

// ---------- Title ----------

class _CodeTitleTab extends StatelessWidget {
  const _CodeTitleTab({
    required this.model,
    required this.editing,
  });

  final CodeBlockModel model;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final style = theme.typo.body.copyWith(color: colors.textPrimary);
    final border = BorderSide(
      color: model.selected ? colors.accent : colors.borderSubtle,
      width: model.selected ? 2 : 1,
    );
    return IntrinsicWidth(
      child: Container(
        constraints: BoxConstraints(minWidth: 76, maxWidth: model.size.width),
        key: ValueKey(editing ? 'code-title-input-tab' : 'code-title-tab'),
        height: 34,
        decoration: BoxDecoration(
          color: model.selected ? colors.accentSoft : colors.surface,
          border: Border(top: border, left: border, right: border),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Semantics(
            label: editing ? null : model.title,
            child: ExcludeSemantics(
              excluding: !editing,
              child: IgnorePointer(
                ignoring: !editing,
                child: TextFormField(
                  key: ValueKey(editing ? 'code-title-input' : 'code-title-text'),
                  initialValue: model.title,
                  style: style,
                  cursorColor: colors.accent,
                  readOnly: !editing,
                  canRequestFocus: editing,
                  showCursor: editing,
                  enableInteractiveSelection: editing,
                  onChanged: (title) => model.title = title,
                  decoration: InputDecoration(
                    hintText: 'Untitled',
                    hintStyle: style.copyWith(color: colors.textMuted),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Settings ----------

/// Presents behavior settings for the active code block.
class CodeToolSettings extends StatelessWidget {
  const CodeToolSettings({
    required this.model,
    required this.onChangeBoundary,
    super.key,
  });

  final CodeBlockModel model;
  final VoidCallback onChangeBoundary;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => CheckboxListTile(
        key: const ValueKey('code-show-line-numbers'),
        value: model.showLineNumbers,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text('Show line numbers', style: theme.typo.label),
        onChanged: (showLineNumbers) {
          onChangeBoundary();
          model.showLineNumbers = showLineNumbers!;
          onChangeBoundary();
        },
      ),
    );
  }
}
