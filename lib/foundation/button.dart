import 'package:flutter/material.dart';

enum ButtonVariant { primary, outline, secondary, ghost, destructive, link }

enum ButtonSize { small, medium, large, icon }

@immutable
class ButtonColors {
  const ButtonColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryHover,
    required this.primaryPressed,
    required this.secondary,
    required this.onSecondary,
    required this.surface,
    required this.foreground,
    required this.border,
    required this.hover,
    required this.pressed,
    required this.focus,
    required this.destructive,
    required this.onDestructive,
    required this.destructiveHover,
    required this.destructivePressed,
    required this.disabled,
    required this.disabledForeground,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryHover;
  final Color primaryPressed;
  final Color secondary;
  final Color onSecondary;
  final Color surface;
  final Color foreground;
  final Color border;
  final Color hover;
  final Color pressed;
  final Color focus;
  final Color destructive;
  final Color onDestructive;
  final Color destructiveHover;
  final Color destructivePressed;
  final Color disabled;
  final Color disabledForeground;
}

class Button extends StatelessWidget {
  const Button({
    required this.colors,
    required this.onPressed,
    this.child,
    this.leadingIcon,
    this.trailingIcon,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    required this.textStyle,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.focusNode,
    this.autofocus = false,
    this.onLongPress,
    super.key,
  }) : assert(
         child != null || leadingIcon != null || trailingIcon != null,
         'A button needs a child or an icon.',
       );

  final ButtonColors colors;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget? child;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final ButtonVariant variant;
  final ButtonSize size;
  final TextStyle textStyle;
  final BorderRadius borderRadius;
  final FocusNode? focusNode;
  final bool autofocus;

  double get _height => switch (size) {
    ButtonSize.small => 32,
    ButtonSize.medium => 40,
    ButtonSize.large => 44,
    ButtonSize.icon => 40,
  };

  double get _horizontalPadding => switch (size) {
    ButtonSize.small => 16,
    ButtonSize.medium => 20,
    ButtonSize.large => 24,
    ButtonSize.icon => 0,
  };

  double get _verticalPadding => switch (size) {
    ButtonSize.small => 6,
    ButtonSize.medium => 8,
    ButtonSize.large => 10,
    ButtonSize.icon => 0,
  };

  double get _iconSize => switch (size) {
    ButtonSize.small => 14,
    ButtonSize.medium => 16,
    ButtonSize.large => 18,
    ButtonSize.icon => 18,
  };

  double get _gap => switch (size) {
    ButtonSize.small => 6,
    ButtonSize.medium => 8,
    ButtonSize.large => 8,
    ButtonSize.icon => 0,
  };

  Color get _foreground => switch (variant) {
    ButtonVariant.primary => colors.onPrimary,
    ButtonVariant.outline => colors.foreground,
    ButtonVariant.secondary => colors.onSecondary,
    ButtonVariant.ghost => colors.foreground,
    ButtonVariant.destructive => colors.onDestructive,
    ButtonVariant.link => colors.primary,
  };

  Color get _background => switch (variant) {
    ButtonVariant.primary => colors.primary,
    ButtonVariant.outline => colors.surface,
    ButtonVariant.secondary => colors.secondary,
    ButtonVariant.ghost || ButtonVariant.link => Colors.transparent,
    ButtonVariant.destructive => colors.destructive,
  };

  Color get _hoverBackground => switch (variant) {
    ButtonVariant.primary => colors.primaryHover,
    ButtonVariant.outline ||
    ButtonVariant.secondary ||
    ButtonVariant.ghost => colors.hover,
    ButtonVariant.destructive => colors.destructiveHover,
    ButtonVariant.link => Colors.transparent,
  };

  Color get _pressedBackground => switch (variant) {
    ButtonVariant.primary => colors.primaryPressed,
    ButtonVariant.outline ||
    ButtonVariant.secondary ||
    ButtonVariant.ghost => colors.pressed,
    ButtonVariant.destructive => colors.destructivePressed,
    ButtonVariant.link => Colors.transparent,
  };

  ButtonStyle _style() {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled)
            ? colors.disabledForeground
            : _foreground;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return variant == ButtonVariant.outline ||
                  variant == ButtonVariant.ghost ||
                  variant == ButtonVariant.link
              ? Colors.transparent
              : colors.disabled;
        }
        if (states.contains(WidgetState.pressed)) return _pressedBackground;
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return _hoverBackground;
        }
        return _background;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return variant == ButtonVariant.outline
              ? BorderSide(color: colors.border.withValues(alpha: 0.38))
              : BorderSide.none;
        }
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: colors.focus, width: 2);
        }
        return variant == ButtonVariant.outline
            ? BorderSide(color: colors.border)
            : BorderSide.none;
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      textStyle: WidgetStateProperty.resolveWith((states) {
        if (variant == ButtonVariant.link &&
            (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused))) {
          return textStyle.copyWith(decoration: TextDecoration.underline);
        }
        return textStyle;
      }),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
      ),
      minimumSize: WidgetStatePropertyAll(Size(0, _height)),
      fixedSize: size == ButtonSize.icon
          ? WidgetStatePropertyAll(Size.square(_height))
          : null,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }

  Widget _content() {
    final children = <Widget>[];
    if (leadingIcon != null) children.add(leadingIcon!);
    if (child != null) children.add(child!);
    if (trailingIcon != null) children.add(trailingIcon!);
    if (children.length == 1) return children.single;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: _gap),
          children[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      focusNode: focusNode,
      autofocus: autofocus,
      style: _style(),
      child: IconTheme.merge(
        data: IconThemeData(size: _iconSize),
        child: _content(),
      ),
    );
  }
}
