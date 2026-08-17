import 'package:flutter/material.dart';

import 'theme.dart';

enum ButtonVariant { primary, outline, secondary, ghost, destructive, link }

enum ButtonSize { small, medium, large, icon }

class Button extends StatelessWidget {
  const Button({
    required this.onPressed,
    this.child,
    this.leadingIcon,
    this.trailingIcon,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.focusNode,
    this.autofocus = false,
    this.onLongPress,
    super.key,
  }) : assert(
         child != null || leadingIcon != null || trailingIcon != null,
         'A button needs a child or an icon.',
       );

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget? child;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final ButtonVariant variant;
  final ButtonSize size;
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

  Color _foreground(BColors colors) => switch (variant) {
    ButtonVariant.primary => colors.surface,
    ButtonVariant.outline ||
    ButtonVariant.secondary ||
    ButtonVariant.ghost => colors.textPrimary,
    ButtonVariant.destructive => colors.accentPressed,
    ButtonVariant.link => colors.accent,
  };

  Color _background(BColors colors) => switch (variant) {
    ButtonVariant.primary => colors.accent,
    ButtonVariant.outline => colors.surface,
    ButtonVariant.secondary => colors.surfaceSubtle,
    ButtonVariant.ghost || ButtonVariant.link => Colors.transparent,
    ButtonVariant.destructive => colors.accentSoft,
  };

  Color _hoverBackground(BColors colors) => switch (variant) {
    ButtonVariant.primary => colors.accentHover,
    ButtonVariant.outline ||
    ButtonVariant.secondary ||
    ButtonVariant.ghost => colors.surfaceHover,
    ButtonVariant.destructive => colors.accentSubtle,
    ButtonVariant.link => Colors.transparent,
  };

  Color _pressedBackground(BColors colors) => switch (variant) {
    ButtonVariant.primary => colors.accentPressed,
    ButtonVariant.outline ||
    ButtonVariant.secondary ||
    ButtonVariant.ghost => colors.surfacePressed,
    ButtonVariant.destructive => colors.accentSubtle,
    ButtonVariant.link => Colors.transparent,
  };

  ButtonStyle _style(
    BColors colors,
    TextStyle textStyle,
    BorderRadius borderRadius,
  ) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled)
            ? colors.textMuted
            : _foreground(colors);
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return variant == ButtonVariant.outline ||
                  variant == ButtonVariant.ghost ||
                  variant == ButtonVariant.link
              ? Colors.transparent
              : colors.surfacePressed;
        }
        if (states.contains(WidgetState.pressed)) {
          return _pressedBackground(colors);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return _hoverBackground(colors);
        }
        return _background(colors);
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return variant == ButtonVariant.outline
              ? BorderSide(color: colors.borderSubtle.withValues(alpha: 0.38))
              : BorderSide.none;
        }
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: colors.focusRing, width: 2);
        }
        return variant == ButtonVariant.outline
            ? BorderSide(color: colors.borderSubtle)
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
    final theme = BTheme.of(context);
    return TextButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      focusNode: focusNode,
      autofocus: autofocus,
      style: _style(theme.colors, theme.typo.body, theme.geo.radiusMedium),
      child: IconTheme.merge(
        data: IconThemeData(size: _iconSize),
        child: _content(),
      ),
    );
  }
}
