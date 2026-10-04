// Gives each app-wide UI component an independently discovered preview.
// Interactive wrappers keep each preview responsible for only its own state.

import 'package:beyond/theme/theme.dart';
import 'package:beyond/ui/common/color_picker.dart';
import 'package:beyond/ui/common/context_menu.dart';
import 'package:beyond/ui/common/discrete_slider.dart';
import 'package:beyond/ui/common/icon_drag.dart';
import 'package:beyond/ui/common/labeled_switch.dart';
import 'package:beyond/ui/common/select.dart';
import 'package:beyond/ui/common/surface.dart';
import 'package:beyond/ui/common/surface_icon_button.dart';
import 'package:beyond/ui/common/surface_text_button.dart';
import 'package:beyond/ui/previews/theme_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';

@Preview(
  name: 'Surface',
  size: Size(400, 240),
  theme: previewTheme,
  brightness: Brightness.light,
)
Widget surfacePreview() => _surface(
  const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Surface(
        child: Padding(padding: EdgeInsets.all(16), child: Text('Default')),
      ),
      SizedBox(width: 12),
      Surface(
        selected: true,
        child: Padding(padding: EdgeInsets.all(16), child: Text('Selected')),
      ),
    ],
  ),
);

@Preview(
  name: 'SurfaceIconButton',
  size: Size(400, 240),
  theme: previewTheme,
  brightness: Brightness.light,
)
Widget surfaceIconButtonPreview() => _surface(
  Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SurfaceIconButton(icon: const Icon(Icons.add), tooltip: 'Add', onPressed: () {}),
      const SizedBox(width: 12),
      SurfaceIconButton(
        icon: const Icon(Icons.check),
        tooltip: 'Done',
        onPressed: () {},
      ),
    ],
  ),
);

@Preview(
  name: 'SurfaceTextButton',
  size: Size(400, 240),
  theme: previewTheme,
  brightness: Brightness.light,
)
Widget surfaceTextButtonPreview() => _surface(
  SurfaceTextButton(
    label: 'New page',
    onPressed: () {},
  ),
);

@Preview(
  name: 'LabeledSwitch',
  size: Size(400, 240),
  theme: previewTheme,
  brightness: Brightness.light,
)
Widget labeledSwitchPreview() => const _LabeledSwitchPreview();

@Preview(
  name: 'IconDrag',
  size: Size(400, 240),
  theme: previewTheme,
  brightness: Brightness.light,
)
Widget iconDragPreview() => _surface(
  IconDrag(
    icon: const Icon(Icons.open_with),
    semanticLabel: 'Drag',
    onDragStart: (_) => null,
  ),
);

@Preview(
  name: 'ColorControl',
  size: Size(320, 420),
  theme: previewTheme,
  brightness: Brightness.light,
)
Widget colorPickerPreview() => const _ColorPickerPreview();

@Preview(
  name: 'ContextMenu',
  size: Size(400, 240),
  theme: previewTheme,
  brightness: Brightness.light,
)
Widget contextMenuPreview() => Builder(
  builder: (context) {
    final theme = BTheme.of(context);
    return _surface(
      ContextMenu(
        semanticLabel: 'Context menu preview',
        groups: [
          [
            ContextMenuAction(
              label: 'Duplicate',
              icon: Icons.copy_outlined,
              shortcut: const SingleActivator(LogicalKeyboardKey.keyD, control: true),
              onPressed: () {},
            ),
            const ContextMenuAction(label: 'Unavailable', icon: Icons.block),
            ContextMenuAction(
              label: 'Arrange',
              icon: Icons.layers_outlined,
              groups: [
                [ContextMenuAction(label: 'Bring Forward', icon: Icons.arrow_upward, onPressed: () {})],
                [ContextMenuAction(label: 'Bring to Front', icon: Icons.flip_to_front, onPressed: () {})],
              ],
            ),
          ],
          [
            ContextMenuAction(
              label: 'Delete',
              icon: Icons.delete_outline,
              destructive: true,
              onPressed: () {},
            ),
          ],
        ],
        child: Container(
          width: 240,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: theme.geo.radiusMedium,
            border: Border.all(color: theme.colors.borderSubtle),
          ),
          child: Text('Click or right-click', style: theme.typo.body),
        ),
      ),
    );
  },
);

@Preview(
  name: 'DiscreteSlider',
  size: Size(400, 240),
  theme: previewTheme,
  brightness: Brightness.light,
)
Widget discreteSliderPreview() => const _DiscreteSliderPreview();

@Preview(
  name: 'Select',
  size: Size(400, 240),
  theme: previewTheme,
  brightness: Brightness.light,
)
Widget selectPreview() => const _SelectPreview();

@Preview(
  name: 'SearchableSelect',
  size: Size(400, 240),
  theme: previewTheme,
  brightness: Brightness.light,
)
Widget searchableSelectPreview() => const _SearchableSelectPreview();

Widget _surface(Widget child) => Builder(
  builder: (context) => ColoredBox(
    color: BTheme.of(context).colors.canvasBackground,
    child: Center(child: child),
  ),
);

class _LabeledSwitchPreview extends StatefulWidget {
  const _LabeledSwitchPreview();

  @override
  State<_LabeledSwitchPreview> createState() => _LabeledSwitchPreviewState();
}

class _LabeledSwitchPreviewState extends State<_LabeledSwitchPreview> {
  var _value = true;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return _surface(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(
            Icons.settings_outlined,
            size: 17,
            color: theme.colors.textSecondary,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 200,
            height: 46,
            child: Surface(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LabeledSwitch(
                  label: 'Show line numbers',
                  value: _value,
                  onChanged: (value) => setState(() => _value = value),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerPreview extends StatefulWidget {
  const _ColorPickerPreview();

  @override
  State<_ColorPickerPreview> createState() => _ColorPickerPreviewState();
}

class _ColorPickerPreviewState extends State<_ColorPickerPreview> {
  Color _color = const Color(0xff3b82f6);
  var _expanded = true;

  @override
  Widget build(BuildContext context) => _surface(
    ColorControl(
      color: _color,
      expanded: _expanded,
      onChanged: (value) => setState(() => _color = value),
      onExpandedChanged: (value) => setState(() => _expanded = value),
    ),
  );
}

class _DiscreteSliderPreview extends StatefulWidget {
  const _DiscreteSliderPreview();

  @override
  State<_DiscreteSliderPreview> createState() => _DiscreteSliderPreviewState();
}

class _DiscreteSliderPreviewState extends State<_DiscreteSliderPreview> {
  double _value = 3;

  @override
  Widget build(BuildContext context) => _surface(
    SizedBox(
      width: 320,
      child: DiscreteSlider(
        value: _value,
        min: 1,
        stepSize: 1,
        onChanged: (next) => setState(() => _value = next),
      ),
    ),
  );
}

const List<SelectOption<String>> _selectOptions = [
  SelectOption(value: 'Canvas', label: 'Canvas'),
  SelectOption(value: 'Dart', label: 'Dart'),
  SelectOption(value: 'Markdown', label: 'Markdown'),
];

class _SelectPreview extends StatefulWidget {
  const _SelectPreview();

  @override
  State<_SelectPreview> createState() => _SelectPreviewState();
}

class _SelectPreviewState extends State<_SelectPreview> {
  String _value = 'Canvas';

  @override
  Widget build(BuildContext context) => _surface(
    Select<String>(
      value: _value,
      options: _selectOptions,
      onChanged: (next) => setState(() => _value = next),
    ),
  );
}

class _SearchableSelectPreview extends StatefulWidget {
  const _SearchableSelectPreview();

  @override
  State<_SearchableSelectPreview> createState() => _SearchableSelectPreviewState();
}

class _SearchableSelectPreviewState extends State<_SearchableSelectPreview> {
  String _value = 'Dart';

  @override
  Widget build(BuildContext context) => _surface(
    SearchableSelect<String>(
      value: _value,
      options: _selectOptions,
      preferredValues: const ['Dart'],
      searchHint: 'Search formats',
      onChanged: (next) => setState(() => _value = next),
    ),
  );
}
