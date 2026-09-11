// Provides the interactive widget-preview entry for the floating color picker.
// Discovered only by Flutter's local widget preview environment.

import 'package:beyond/theme/starless.dart';
import 'package:beyond/ui/common/color_picker.dart';
import 'package:beyond/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

// ---------- Preview ----------

PreviewThemeData colorPickerPreviewTheme() {
  return PreviewThemeData(materialLight: starlessLightThemeData);
}

@Preview(
  name: 'Floating color picker',
  size: Size(280, 350),
  theme: colorPickerPreviewTheme,
  brightness: Brightness.light,
)
Widget colorPickerPreview() {
  return Builder(
    builder: (context) {
      final colors = BTheme.of(context).colors;
      return ColoredBox(
        color: colors.canvasBackground,
        child: Center(
          child: ColorPickerWidget(
            color: const Color(0xff3b82f6),
            onChanged: (_) {},
          ),
        ),
      );
    },
  );
}
