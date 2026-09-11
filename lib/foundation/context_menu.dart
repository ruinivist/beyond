// Provides Beyond's themed context menu and action model.
// Used by interactive surfaces that expose grouped pointer actions.

import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';

// ---------- Models ----------

class BContextMenuAction {
  const BContextMenuAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.shortcut,
    this.destructive = false,
    this.autofocus = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final MenuSerializableShortcut? shortcut;
  final bool destructive;
  final bool autofocus;
}

// ---------- Widgets ----------

/// Renders a context menu around a pointer-interactive child.
/// Used by canvas elements and other surfaces with grouped actions.
class BContextMenu extends StatelessWidget {
  const BContextMenu({
    required this.groups,
    required this.child,
    this.semanticLabel,
    this.semanticHint,
    super.key,
  });

  final List<List<BContextMenuAction>> groups;
  final Widget child;
  final String? semanticLabel;
  final String? semanticHint;

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

  Widget _item(BuildContext context, BContextMenuAction action) {
    final item = MenuItemButton(
      autofocus: action.autofocus,
      onPressed: action.onPressed,
      shortcut: action.shortcut,
      style: _itemStyle(
        BTheme.of(context),
        destructive: action.destructive,
      ),
      leadingIcon: Icon(action.icon, size: 16),
      child: Text(action.label),
    );
    return SizedBox(
      width: _menuWidth,
      child: item,
    );
  }

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return MenuAnchor(
      consumeOutsideTap: true,
      style: _menuStyle(theme),
      menuChildren: [
        for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) ...[
          if (groupIndex > 0)
            SizedBox(
              width: _menuWidth,
              child: Divider(height: 8, color: theme.colors.borderSubtle),
            ),
          for (final action in groups[groupIndex]) _item(context, action),
        ],
      ],
      builder: (context, controller, child) => Semantics(
        label: semanticLabel,
        hint: semanticHint,
        button: true,
        child: InkWell(
          mouseCursor: SystemMouseCursors.contextMenu,
          onTap: controller.open,
          onSecondaryTapDown: (details) => controller.open(position: details.localPosition),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
