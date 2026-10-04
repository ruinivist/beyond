// Provides elseplane's raised text action.
// Used for app-wide actions that need a text label.

import 'package:elseplane/theme/theme.dart';
import 'package:elseplane/ui/common/surface.dart';
import 'package:flutter/material.dart';

// ---------- Widgets ----------

class SurfaceTextButton extends StatelessWidget {
  // ---------- Construction ----------

  const SurfaceTextButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    return Surface(
      child: TextButton(
        onPressed: onPressed,
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(
            theme.colors.textPrimary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return theme.colors.surfacePressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return theme.colors.surfaceHover;
            }
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: theme.geo.radiusLarge),
          ),
          textStyle: WidgetStatePropertyAll(theme.typo.body),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          ),
          fixedSize: const WidgetStatePropertyAll(BSizes.defaultTextButtonSize),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
        ),
        child: Text(label),
      ),
    );
  }
}
