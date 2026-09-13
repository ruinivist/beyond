// Renders the settings panel for the canvas text tool.
// Used by the editor's tool-options overlay for the active text element.

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/tools/text/text_block_model.dart';
import 'package:beyond/theme/theme.dart';
import 'package:beyond/ui/common/color_picker.dart';
import 'package:beyond/ui/common/select.dart';
import 'package:flutter/material.dart';

// ---------- Font options ----------

final List<SelectOption<String>> textFontOptions = [
  for (final fontFamily in textNodeFontFamilies) SelectOption(value: fontFamily, label: fontFamily),
];

// ---------- Settings ----------

/// Presents font and color controls for the active text element.
/// Used by the canvas tool-options overlay during text editing.
class TextToolSettings extends StatelessWidget {
  const TextToolSettings({
    required this.model,
    required this.onChangeBoundary,
    required this.colorPickerExpanded,
    required this.onColorPickerExpandedChanged,
    super.key,
  });

  final TextBlockModel model;
  final VoidCallback onChangeBoundary;
  final bool colorPickerExpanded;
  final ValueChanged<bool> onColorPickerExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final style = model.style;
        final selectedColor = colorFromHex(style.color);
        return Column(
          key: const ValueKey('text-settings-panel'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Font', style: theme.typo.label),
            const SizedBox(height: 6),
            Select<String>(
              key: const ValueKey('text-font-select'),
              value: style.fontFamily,
              options: textFontOptions,
              onChanged: (fontFamily) {
                onChangeBoundary();
                model.style = style.copyWith(fontFamily: fontFamily);
                onChangeBoundary();
              },
            ),
            const SizedBox(height: 10),
            Text('Color', style: theme.typo.label),
            const SizedBox(height: 6),
            ColorControl(
              color: selectedColor,
              expanded: colorPickerExpanded,
              enableAlpha: false,
              onExpandedChanged: onColorPickerExpandedChanged,
              onChanged: (color) {
                onChangeBoundary();
                model.style = style.copyWith(color: colorToHex(color));
                onChangeBoundary();
              },
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              key: const ValueKey('text-no-fill'),
              value: style.noFill,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('No Fill', style: theme.typo.label),
              onChanged: (noFill) {
                onChangeBoundary();
                model.style = style.copyWith(noFill: noFill);
                onChangeBoundary();
              },
            ),
          ],
        );
      },
    );
  }
}

// ---------- Color conversion ----------

String colorToHex(Color color) {
  final value = color.toARGB32() & 0x00ffffff;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color colorFromHex(String value) {
  return Color(int.parse('FF${value.substring(1)}', radix: 16));
}
