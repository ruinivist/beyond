import 'dart:math' as math;

import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class SelectOption<T> {
  const SelectOption({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;
  final bool enabled;
}

const _selectMinimumWidth = 160.0;
const _selectTriggerHeight = 36.0;
const _selectTriggerHorizontalPadding = 16.0;
const _selectTriggerIconSize = 16.0;

double _selectPreferredWidth<T>(
  BuildContext context,
  List<SelectOption<T>> options,
  TextStyle textStyle,
) {
  var widestLabel = 0.0;
  for (final option in options) {
    widestLabel = math.max(
      widestLabel,
      TextPainter.computeWidth(
        text: TextSpan(text: option.label, style: textStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      ),
    );
  }
  return math.max(
    _selectMinimumWidth,
    widestLabel + _selectTriggerHorizontalPadding * 2 + _selectTriggerIconSize,
  );
}

WidgetStateProperty<Color?> _selectForegroundColor(BColors colors) {
  return WidgetStateProperty.resolveWith((states) {
    return states.contains(WidgetState.disabled)
        ? colors.textPrimary.withValues(alpha: 0.38)
        : colors.textPrimary;
  });
}

ButtonStyle _selectTriggerStyle({
  required BTheme theme,
  required bool showBorder,
  required double width,
}) {
  final colors = theme.colors;
  return ButtonStyle(
    foregroundColor: _selectForegroundColor(colors),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return colors.surface;
      if (states.contains(WidgetState.pressed)) return colors.surfacePressed;
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return colors.surfaceHover;
      }
      return colors.surface;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (!showBorder) return const BorderSide(color: Colors.transparent);
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(color: colors.borderSubtle.withValues(alpha: 0.38));
      }
      return BorderSide(color: colors.borderSubtle);
    }),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: theme.geo.radiusMedium),
    ),
    textStyle: WidgetStatePropertyAll(theme.typo.body),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(
        horizontal: _selectTriggerHorizontalPadding,
        vertical: 6,
      ),
    ),
    fixedSize: WidgetStatePropertyAll(Size(width, _selectTriggerHeight)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    alignment: Alignment.centerLeft,
  );
}

ButtonStyle _selectOptionStyle({
  required BTheme theme,
  required bool isSelected,
}) {
  final colors = theme.colors;
  return ButtonStyle(
    foregroundColor: _selectForegroundColor(colors),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      if (isSelected) return Colors.transparent;
      if (states.contains(WidgetState.pressed)) return colors.surfacePressed;
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return colors.surfaceHover;
      }
      return Colors.transparent;
    }),
    backgroundBuilder: isSelected
        ? (context, states, child) => Stack(
            children: [
              if (!states.contains(WidgetState.disabled))
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfacePressed,
                        borderRadius: theme.geo.radiusSmall,
                      ),
                    ),
                  ),
                ),
              child ?? const SizedBox.shrink(),
            ],
          )
        : null,
    textStyle: WidgetStatePropertyAll(theme.typo.body),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    alignment: Alignment.centerLeft,
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: theme.geo.radiusSmall),
    ),
  );
}

MenuStyle _selectMenuStyle({
  required BTheme theme,
  required double Function() width,
}) {
  final colors = theme.colors;
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(colors.surfaceRaised),
    shadowColor: WidgetStatePropertyAll(colors.shadow),
    elevation: WidgetStatePropertyAll(theme.geo.elevationMedium),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
    minimumSize: const WidgetStatePropertyAll(Size.zero),
    fixedSize: WidgetStateProperty.resolveWith((_) => Size.fromWidth(width())),
    maximumSize: const WidgetStatePropertyAll(Size.infinite),
    visualDensity: VisualDensity.standard,
    side: WidgetStatePropertyAll(BorderSide(color: colors.borderSubtle)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: theme.geo.radiusMedium),
    ),
    alignment: AlignmentDirectional.bottomStart,
  );
}

Widget _buildSelectTrigger({
  required GlobalKey triggerKey,
  required FocusNode focusNode,
  required MenuController controller,
  required bool enabled,
  required String label,
  required String keyPrefix,
  required BTheme theme,
  required bool showBorder,
  required double width,
}) {
  return Semantics(
    key: triggerKey,
    container: true,
    button: true,
    enabled: enabled,
    expanded: controller.isOpen,
    child: CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          if (enabled && !controller.isOpen) controller.open();
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          if (enabled && !controller.isOpen) controller.open();
        },
      },
      child: TapRegion(
        groupId: controller,
        onTapUpOutside: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FocusManager.instance.applyFocusChangesIfNeeded();
            if (focusNode.hasFocus) focusNode.unfocus();
          });
        },
        child: TextButton(
          key: ValueKey('$keyPrefix-trigger'),
          onPressed: enabled
              ? () => controller.isOpen ? controller.close() : controller.open()
              : null,
          focusNode: focusNode,
          style: _selectTriggerStyle(
            theme: theme,
            showBorder: showBorder,
            width: width,
          ),
          child: Row(
            children: [
              Text(label),
              const Spacer(),
              Icon(
                Icons.keyboard_arrow_down,
                size: _selectTriggerIconSize,
                color: theme.colors.textPrimary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildSelectOption<T>({
  required SelectOption<T> option,
  required int index,
  required T value,
  required FocusNode? focusNode,
  required ValueChanged<T>? onChanged,
  required BTheme theme,
  required String keyPrefix,
}) {
  final isSelected = option.value == value;
  return Semantics(
    container: true,
    selected: isSelected,
    inMutuallyExclusiveGroup: true,
    child: MenuItemButton(
      key: ValueKey('$keyPrefix-option-$index'),
      focusNode: focusNode,
      onPressed: option.enabled
          ? () {
              // MenuItemButton restores focus before calling onPressed.
              FocusManager.instance.primaryFocus?.unfocus();
              onChanged?.call(option.value);
            }
          : null,
      semanticsLabel: option.label,
      style: _selectOptionStyle(theme: theme, isSelected: isSelected),
      child: Text(option.label),
    ),
  );
}

class Select<T> extends StatefulWidget {
  const Select({
    required this.value,
    required this.options,
    required this.onChanged,
    this.showBorder = true,
    super.key,
  });

  final T value;
  final List<SelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final bool showBorder;

  @override
  State<Select<T>> createState() => _SelectState<T>();
}

class _SelectState<T> extends State<Select<T>> {
  final _menuController = MenuController();
  final GlobalKey _triggerKey = GlobalKey();
  final _triggerFocusNode = FocusNode();
  late List<FocusNode> _optionFocusNodes;

  bool get _enabled => widget.onChanged != null;
  BTheme get _theme => BTheme.of(context);
  TextStyle get _textStyle => _theme.typo.body;
  double get _preferredWidth =>
      _selectPreferredWidth(context, widget.options, _textStyle);

  double get _triggerWidth {
    final renderBox = _triggerKey.currentContext?.findRenderObject();
    return renderBox is RenderBox && renderBox.hasSize
        ? renderBox.size.width
        : _preferredWidth;
  }

  @override
  void initState() {
    super.initState();
    _optionFocusNodes = _newOptionFocusNodes(widget.options.length);
  }

  @override
  void didUpdateWidget(covariant Select<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      for (final node in _optionFocusNodes) {
        node.dispose();
      }
      _optionFocusNodes = _newOptionFocusNodes(widget.options.length);
    }
    if (!_enabled && oldWidget.onChanged != null) {
      _menuController.close();
    }
  }

  List<FocusNode> _newOptionFocusNodes(int count) {
    return List.generate(
      count,
      (i) => FocusNode(debugLabel: 'Select option $i'),
    );
  }

  @override
  void dispose() {
    for (final node in _optionFocusNodes) {
      node.dispose();
    }
    _triggerFocusNode.dispose();
    super.dispose();
  }

  SelectOption<T>? get _selectedOption {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return null;
  }

  void _focusSelectedOption() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_menuController.isOpen) return;
      var index = widget.options.indexWhere(
        (option) => option.value == widget.value && option.enabled,
      );
      if (index < 0) {
        index = widget.options.indexWhere((option) => option.enabled);
      }
      if (index >= 0) _optionFocusNodes[index].requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOption;
    return MenuAnchor(
      key: const ValueKey('select-menu'),
      controller: _menuController,
      childFocusNode: _triggerFocusNode,
      onOpen: _focusSelectedOption,
      alignmentOffset: const Offset(0, 4),
      crossAxisUnconstrained: false,
      style: _selectMenuStyle(theme: _theme, width: () => _triggerWidth),
      menuChildren: [
        for (var i = 0; i < widget.options.length; i++)
          _buildOption(widget.options[i], i),
      ],
      builder: (context, controller, child) => _buildSelectTrigger(
        triggerKey: _triggerKey,
        focusNode: _triggerFocusNode,
        controller: controller,
        enabled: _enabled,
        label: selected?.label ?? '',
        keyPrefix: 'select',
        theme: _theme,
        showBorder: widget.showBorder,
        width: _preferredWidth,
      ),
    );
  }

  Widget _buildOption(SelectOption<T> option, int index) {
    return _buildSelectOption(
      option: option,
      index: index,
      value: widget.value,
      focusNode: _optionFocusNodes[index],
      onChanged: widget.onChanged,
      theme: _theme,
      keyPrefix: 'select',
    );
  }
}

class SearchableSelect<T> extends StatefulWidget {
  const SearchableSelect({
    required this.value,
    required this.options,
    required this.searchHint,
    required this.onChanged,
    this.preferredValues = const [],
    this.showBorder = true,
    super.key,
  });

  final T value;
  final List<SelectOption<T>> options;
  final List<T> preferredValues;
  final String searchHint;
  final ValueChanged<T>? onChanged;
  final bool showBorder;

  @override
  State<SearchableSelect<T>> createState() => _SearchableSelectState<T>();
}

class _SearchableSelectState<T> extends State<SearchableSelect<T>> {
  final _menuController = MenuController();
  final GlobalKey _triggerKey = GlobalKey();
  final _triggerFocusNode = FocusNode();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'Searchable select search');

  bool get _enabled => widget.onChanged != null;
  BTheme get _theme => BTheme.of(context);
  BColors get _colors => _theme.colors;
  TextStyle get _textStyle => _theme.typo.body;
  double get _preferredWidth =>
      _selectPreferredWidth(context, widget.options, _textStyle);

  double get _triggerWidth {
    final renderBox = _triggerKey.currentContext?.findRenderObject();
    return renderBox is RenderBox && renderBox.hasSize
        ? renderBox.size.width
        : _preferredWidth;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant SearchableSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && oldWidget.onChanged != null) {
      _menuController.close();
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _searchFocusNode.dispose();
    _triggerFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  void _prepareSearch() {
    _searchController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_menuController.isOpen) return;
      _searchFocusNode.requestFocus();
    });
  }

  List<SelectOption<T>> get _visibleOptions {
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      return widget.options
          .where((option) => option.label.toLowerCase().contains(query))
          .toList()
        ..sort(_compareOptions);
    }

    final preferred = <SelectOption<T>>[];
    for (final value in widget.preferredValues) {
      SelectOption<T>? option;
      for (final candidate in widget.options) {
        if (candidate.value == value) {
          option = candidate;
          break;
        }
      }
      if (option != null &&
          !preferred.any((current) => current.value == option!.value)) {
        preferred.add(option);
      }
    }

    final remaining =
        widget.options
            .where(
              (option) =>
                  !preferred.any((current) => current.value == option.value),
            )
            .toList()
          ..sort(_compareOptions);
    return [...preferred, ...remaining];
  }

  int _compareOptions(SelectOption<T> a, SelectOption<T> b) {
    final comparison = a.label.toLowerCase().compareTo(b.label.toLowerCase());
    return comparison == 0 ? a.label.compareTo(b.label) : comparison;
  }

  SelectOption<T>? get _selectedOption {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOption;
    final menuWidth = _triggerWidth - 8;
    final visibleOptions = _visibleOptions;
    return MenuAnchor(
      key: const ValueKey('searchable-select-menu'),
      controller: _menuController,
      childFocusNode: _triggerFocusNode,
      onOpen: _prepareSearch,
      alignmentOffset: const Offset(0, 4),
      crossAxisUnconstrained: false,
      style: _selectMenuStyle(theme: _theme, width: () => _triggerWidth),
      menuChildren: [
        SizedBox(
          width: menuWidth,
          child: TextField(
            key: const ValueKey('searchable-select-search'),
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: _textStyle,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              hintStyle: _textStyle.copyWith(color: _colors.textMuted),
              isDense: true,
              filled: true,
              fillColor: _colors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: _theme.geo.radiusSmall,
                borderSide: BorderSide(color: _colors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: _theme.geo.radiusSmall,
                borderSide: BorderSide(color: _colors.focusRing, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (visibleOptions.isEmpty)
          SizedBox(
            width: menuWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Text(
                'No results',
                style: _textStyle.copyWith(color: _colors.textSecondary),
              ),
            ),
          )
        else
          SizedBox(
            width: menuWidth,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                padding: EdgeInsets.zero,
                primary: false,
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < visibleOptions.length; i++)
                    _buildSearchableOption(visibleOptions[i], i),
                ],
              ),
            ),
          ),
      ],
      builder: (context, controller, child) => _buildSelectTrigger(
        triggerKey: _triggerKey,
        focusNode: _triggerFocusNode,
        controller: controller,
        enabled: _enabled,
        label: selected?.label ?? '',
        keyPrefix: 'searchable-select',
        theme: _theme,
        showBorder: widget.showBorder,
        width: _preferredWidth,
      ),
    );
  }

  Widget _buildSearchableOption(SelectOption<T> option, int index) {
    return _buildSelectOption(
      option: option,
      index: index,
      value: widget.value,
      focusNode: null,
      onChanged: (value) {
        widget.onChanged?.call(value);
        _menuController.close();
      },
      theme: _theme,
      keyPrefix: 'searchable-select',
    );
  }
}
