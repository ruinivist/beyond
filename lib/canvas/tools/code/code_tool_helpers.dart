// Provides the code tool's compact title, language, and settings controls.
// Used internally by code rendering and by the active-element settings panel.

part of 'code_tool.dart';

// ---------- Geometry ----------

const _codeTitleHeight = 34.0;
const _codeControlInset = 8.0;
const _codeEditorPadding = 10.0;

// ---------- Title ----------

class _CodeTitleTab extends StatelessWidget {
  const _CodeTitleTab({
    required this.model,
    required this.editing,
    required this.maxWidth,
  });

  final CodeBlockModel model;
  final bool editing;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final style = theme.typo.body.copyWith(color: colors.textPrimary);
    final label = model.title.isEmpty ? 'Untitled' : model.title;
    final labelWidth = TextPainter.computeWidth(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    final width = (labelWidth + 24).clamp(76.0, maxWidth);
    final border = BorderSide(
      color: model.selected ? colors.accent : colors.borderSubtle,
      width: model.selected ? 2 : 1,
    );
    return Container(
      key: ValueKey(editing ? 'code-title-input-tab' : 'code-title-tab'),
      width: width,
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
      child: editing
          ? TextFormField(
              key: const ValueKey('code-title-input'),
              initialValue: model.title,
              style: style,
              cursorColor: colors.accent,
              onChanged: (title) => model.title = title,
              decoration: InputDecoration(
                hintText: 'Untitled',
                hintStyle: style.copyWith(color: colors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                model.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
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
