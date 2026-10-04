// Provides Beyond's themed context menu and action model.
// Used by interactive surfaces that expose grouped pointer actions.

import 'package:beyond/theme/theme.dart';
import 'package:flutter/material.dart';

// ---------- Models ----------

class ContextMenuAction {
  const ContextMenuAction({
    required this.label,
    required this.icon,
    this.onPressed,
    this.shortcut,
    this.destructive = false,
    this.groups = const [],
    this.focusNode,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final MenuSerializableShortcut? shortcut;
  final bool destructive;
  final List<List<ContextMenuAction>> groups;
  final FocusNode? focusNode;
}

// ---------- Widgets ----------

/// Renders a context menu around a pointer-interactive child.
/// Used by canvas elements and other surfaces with grouped actions.
class ContextMenu extends StatelessWidget {
  const ContextMenu({
    required this.groups,
    required this.child,
    this.semanticLabel,
    this.controller,
    this.onClose,
    this.tapRegionGroupId,
    super.key,
  });

  final List<List<ContextMenuAction>> groups;
  final Widget child;
  final String? semanticLabel;
  final MenuController? controller;
  final VoidCallback? onClose;
  final Object? tapRegionGroupId;

  static const _menuWidth = 224.0;

  // ---------- Styling ----------

  MenuStyle _menuStyle(BTheme theme) {
    final colors = theme.colors;
    return MenuStyle(
      backgroundColor: WidgetStatePropertyAll(colors.surfaceRaised),
      shadowColor: WidgetStatePropertyAll(colors.shadow),
      elevation: WidgetStatePropertyAll(theme.geo.elevationMedium),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
      minimumSize: const WidgetStatePropertyAll(Size(_menuWidth, 0)),
      side: WidgetStatePropertyAll(BorderSide(color: colors.borderSubtle)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: theme.geo.radiusMedium),
      ),
    );
  }

  ButtonStyle _itemStyle(BTheme theme, {required bool destructive}) {
    final colors = theme.colors;
    final foreground = destructive ? colors.accentPressed : colors.textPrimary;
    return MenuItemButton.styleFrom(
      foregroundColor: foreground,
      disabledForegroundColor: colors.textMuted,
      iconColor: foreground,
      disabledIconColor: colors.textMuted,
      backgroundColor: Colors.transparent,
      disabledBackgroundColor: Colors.transparent,
      textStyle: theme.typo.body,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.centerLeft,
      shape: RoundedRectangleBorder(borderRadius: theme.geo.radiusSmall),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return colors.surfacePressed;
        if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
          return colors.surfaceHover;
        }
        return Colors.transparent;
      }),
    );
  }

  // ---------- Composition ----------

  Widget _item(BuildContext context, ContextMenuAction action) {
    final theme = BTheme.of(context);
    final style = _itemStyle(theme, destructive: action.destructive);
    final item = action.groups.isNotEmpty
        ? SubmenuButton(
            focusNode: action.focusNode,
            style: style,
            menuStyle: _menuStyle(theme),
            leadingIcon: Icon(action.icon, size: 16),
            menuChildren: _items(context, action.groups),
            child: Text(action.label),
          )
        : MenuItemButton(
            focusNode: action.focusNode,
            onPressed: action.onPressed,
            shortcut: action.shortcut,
            style: style,
            leadingIcon: Icon(action.icon, size: 16),
            child: Text(action.label),
          );
    return SizedBox(
      width: _menuWidth,
      child: item,
    );
  }

  List<Widget> _items(BuildContext context, List<List<ContextMenuAction>> groups) => [
    for (var index = 0; index < groups.length; index++) ...[
      if (index > 0)
        SizedBox(
          width: _menuWidth,
          child: Divider(height: 8, color: BTheme.of(context).colors.borderSubtle),
        ),
      for (final action in groups[index])
        if (tapRegionGroupId != null)
          TapRegion(
            groupId: tapRegionGroupId,
            child: _item(context, action),
          )
        else
          _item(context, action),
    ],
  ];

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return MenuAnchor(
      consumeOutsideTap: true,
      style: _menuStyle(theme),
      controller: controller,
      onClose: onClose,
      menuChildren: _items(context, groups),
      builder: (context, menuController, child) => controller != null
          ? child!
          : Semantics(
              label: semanticLabel,
              button: true,
              child: InkWell(
                mouseCursor: SystemMouseCursors.contextMenu,
                onTap: menuController.open,
                onSecondaryTapDown: (details) => menuController.open(position: details.localPosition),
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) return theme.colors.surfacePressed;
                  if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
                    return theme.colors.surfaceHover;
                  }
                  return Colors.transparent;
                }),
                child: child,
              ),
            ),
      child: child,
    );
  }
}
