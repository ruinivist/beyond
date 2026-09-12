// Renders the settings panel for the canvas text tool.
// Used by the editor's tool-options overlay for the active text element.

import 'package:beyond/canvas/tools/text/text_block_model.dart';
import 'package:beyond/theme/preset_colors.dart';
import 'package:beyond/theme/theme.dart';
import 'package:beyond/ui/common/select.dart';
import 'package:flutter/material.dart';

// ---------- Font options ----------

const textFontOptions = <SelectOption<String>>[
  SelectOption(value: 'Source Serif 4', label: 'Source Serif 4'),
  SelectOption(value: 'Inter', label: 'Inter'),
  SelectOption(value: 'Roboto Mono', label: 'Roboto Mono'),
];

// ---------- Settings ----------

/// Presents font and color controls for the active text element.
/// Used by the canvas tool-options overlay during text editing.
class TextToolSettings extends StatelessWidget {
  const TextToolSettings({
    required this.model,
    required this.onChangeBoundary,
    super.key,
  });

  final TextBlockModel model;
  final VoidCallback onChangeBoundary;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final style = model.style;
        final selectedColor = colorFromHex(style.color);
        return SizedBox(
          key: const ValueKey('text-settings-panel'),
          width: 248,
          child: Column(
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
              Wrap(
                children: [
                  for (final swatch in presetColors)
                    Tooltip(
                      message: swatch.label,
                      child: Semantics(
                        button: true,
                        selected: selectedColor == swatch.color,
                        label: 'Use ${swatch.label}',
                        child: IconButton(
                          key: ValueKey('text-color-${swatch.label}'),
                          onPressed: () {
                            onChangeBoundary();
                            model.style = style.copyWith(
                              color: colorToHex(swatch.color),
                            );
                            onChangeBoundary();
                          },
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(40),
                            padding: const EdgeInsets.all(8),
                            shape: const CircleBorder(),
                            side: BorderSide(
                              color: selectedColor == swatch.color ? colors.focusRing : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          icon: DecoratedBox(
                            decoration: BoxDecoration(
                              color: swatch.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: const SizedBox.square(dimension: 20),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
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
