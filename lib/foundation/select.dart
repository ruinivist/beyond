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

class Select<T> extends StatefulWidget {
  const Select({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<SelectOption<T>> options;
  final ValueChanged<T>? onChanged;

  @override
  State<Select<T>> createState() => _SelectState<T>();
}

class _SelectState<T> extends State<Select<T>> {
  static const double _minimumWidth = 160;
  static const double _triggerHeight = 36;
  static const double _triggerHorizontalPadding = 16;
  static const double _triggerIconSize = 16;

  final _menuController = MenuController();
  final GlobalKey _triggerKey = GlobalKey();
  final _triggerFocusNode = FocusNode();
  late List<FocusNode> _optionFocusNodes;

  bool get _enabled => widget.onChanged != null;
  BTheme get _theme => BTheme.of(context);
  BColors get _colors => _theme.colors;
  BGeo get _geo => _theme.geo;
  TextStyle get _textStyle => _theme.typo.body;
  Color get _foreground => _colors.textPrimary;
  Color get _background => _colors.surface;
  Color get _popup => _colors.surfaceRaised;
  Color get _border => _colors.borderSubtle;
  Color get _hover => _colors.surfaceHover;
  Color get _pressed => _colors.surfacePressed;
  Color get _shadow => _colors.shadow;
  double get _preferredWidth {
    var widestLabel = 0.0;
    for (final option in widget.options) {
      widestLabel = math.max(
        widestLabel,
        TextPainter.computeWidth(
          text: TextSpan(text: option.label, style: _textStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        ),
      );
    }
    return math.max(
      _minimumWidth,
      widestLabel + _triggerHorizontalPadding * 2 + _triggerIconSize,
    );
  }

  double get _triggerWidth {
    final renderBox = _triggerKey.currentContext?.findRenderObject();
    return renderBox is RenderBox && renderBox.hasSize
        ? renderBox.size.width
        : _preferredWidth;
  }

  WidgetStateProperty<Color?> get _foregroundColor =>
      WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled)
            ? _foreground.withValues(alpha: 0.38)
            : _foreground;
      });

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

  void _restoreTriggerFocus() {
    if (mounted && _enabled) _triggerFocusNode.requestFocus();
  }

  ButtonStyle _triggerStyle() {
    return ButtonStyle(
      foregroundColor: _foregroundColor,
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return _background;
        }
        if (states.contains(WidgetState.pressed)) return _pressed;
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return _hover;
        }
        return _background;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: _border.withValues(alpha: 0.38));
        }
        return BorderSide(color: _border);
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: _geo.radiusMedium),
      ),
      textStyle: WidgetStatePropertyAll(_textStyle),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: _triggerHorizontalPadding,
          vertical: 6,
        ),
      ),
      fixedSize: WidgetStatePropertyAll(
        Size(_preferredWidth, _triggerHeight),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.centerLeft,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }

  ButtonStyle _optionStyle(bool isSelected) {
    return ButtonStyle(
      foregroundColor: _foregroundColor,
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (isSelected) return Colors.transparent;
        if (states.contains(WidgetState.pressed)) return _pressed;
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return _hover;
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
                          color: _pressed,
                          borderRadius: _geo.radiusSmall,
                        ),
                      ),
                    ),
                  ),
                child ?? const SizedBox.shrink(),
              ],
            )
          : null,
      textStyle: WidgetStatePropertyAll(_textStyle),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.centerLeft,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: _geo.radiusSmall),
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOption;
    return MenuAnchor(
      key: const ValueKey('select-menu'),
      controller: _menuController,
      childFocusNode: _triggerFocusNode,
      onOpen: _focusSelectedOption,
      onClose: _restoreTriggerFocus,
      alignmentOffset: const Offset(0, 4),
      crossAxisUnconstrained: false,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(_popup),
        shadowColor: WidgetStatePropertyAll(_shadow),
        elevation: WidgetStatePropertyAll(_geo.elevationMedium),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
        minimumSize: const WidgetStatePropertyAll(Size.zero),
        fixedSize: WidgetStateProperty.resolveWith(
          (_) => Size.fromWidth(_triggerWidth),
        ),
        maximumSize: const WidgetStatePropertyAll(Size.infinite),
        visualDensity: VisualDensity.standard,
        side: WidgetStatePropertyAll(BorderSide(color: _border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: _geo.radiusMedium),
        ),
        alignment: AlignmentDirectional.bottomStart,
      ),
      menuChildren: [
        for (var i = 0; i < widget.options.length; i++)
          _buildOption(widget.options[i], i),
      ],
      builder: (context, controller, child) => Semantics(
        key: _triggerKey,
        container: true,
        button: true,
        enabled: _enabled,
        expanded: controller.isOpen,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.arrowDown): () {
              if (_enabled && !controller.isOpen) controller.open();
            },
            const SingleActivator(LogicalKeyboardKey.arrowUp): () {
              if (_enabled && !controller.isOpen) controller.open();
            },
          },
          child: TextButton(
            key: const ValueKey('select-trigger'),
            onPressed: _enabled
                ? () =>
                      controller.isOpen ? controller.close() : controller.open()
                : null,
            focusNode: _triggerFocusNode,
            style: _triggerStyle(),
            child: Row(
              children: [
                Text(selected?.label ?? ''),
                const Spacer(),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: _triggerIconSize,
                  color: _foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(SelectOption<T> option, int index) {
    final isSelected = option.value == widget.value;
    return Semantics(
      container: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: MenuItemButton(
        key: ValueKey('select-option-$index'),
        focusNode: _optionFocusNodes[index],
        onPressed: option.enabled
            ? () => widget.onChanged?.call(option.value)
            : null,
        semanticsLabel: option.label,
        style: _optionStyle(isSelected),
        child: Text(option.label),
      ),
    );
  }
}
