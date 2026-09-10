// Provides the animated surface that hosts active tool options.
// Used by the canvas toolbar when switching editing tools.

import 'package:beyond/foundation/control_surface.dart';
import 'package:flutter/material.dart';

// ---------- Widgets ----------

class ToolOptions extends StatelessWidget {
  // ---------- Construction ----------

  const ToolOptions({required this.child, super.key});

  final Widget? child;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topRight,
        clipBehavior: Clip.none,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        if (child.key == const ValueKey('tool-options-hidden')) return child;
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ControlSurface(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: child,
              ),
            ),
          ),
        );
      },
      child:
          child ?? const SizedBox.shrink(key: ValueKey('tool-options-hidden')),
    );
  }
}
