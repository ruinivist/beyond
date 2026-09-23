// Provides the canvas name with a hover-revealed breadcrumb path.
// Used by the canvas editor UI and its isolated component preview.

import 'package:beyond/theme/theme.dart';
import 'package:flutter/material.dart';

// ---------- Canvas title ----------

class CanvasTitle extends StatefulWidget {
  // ---------- Construction ----------

  const CanvasTitle({required this.path, this.onPressed, super.key});

  final List<String> path;
  final VoidCallback? onPressed;

  @override
  State<CanvasTitle> createState() => _CanvasTitleState();
}

class _CanvasTitleState extends State<CanvasTitle> {
  // ---------- Constants ----------

  static const _animationDuration = Duration(milliseconds: 150);
  static const _height = 40.0;

  // ---------- State ----------

  var _hovered = false;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final textStyle = theme.typo.body.copyWith(
      color: theme.colors.textMuted,
      fontSize: 12,
    );

    return Semantics(
      label: widget.path.join(' / '),
      button: widget.onPressed != null,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: theme.geo.radiusSmall,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Container(
            height: _height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.path.length > 1)
                  TweenAnimationBuilder<double>(
                    duration: _animationDuration,
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: _hovered ? 1 : 0),
                    child: Text(
                      '${widget.path.take(widget.path.length - 1).join(' / ')} / ',
                      style: textStyle,
                    ),
                    builder: (context, value, child) => ClipRect(
                      child: Align(
                        alignment: Alignment.centerRight,
                        widthFactor: value,
                        child: Opacity(opacity: value, child: child),
                      ),
                    ),
                  ),
                Text(widget.path.last, style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
