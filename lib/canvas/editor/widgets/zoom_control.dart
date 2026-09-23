// Provides the canvas zoom readout and compact zoom actions.
// Used by the editor as a viewport-anchored secondary control.

import 'package:beyond/canvas/editor/widgets/toolbar_button.dart';
import 'package:beyond/theme/theme.dart';
import 'package:beyond/ui/common/b_container.dart';
import 'package:flutter/material.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ---------- Zoom control ----------

class ZoomControl extends StatefulWidget {
  // ---------- Construction ----------

  const ZoomControl({required this.controller, super.key});

  final LazyCanvasController controller;

  @override
  State<ZoomControl> createState() => _ZoomControlState();
}

class _ZoomControlState extends State<ZoomControl> {
  // ---------- Constants ----------

  static const _animationDuration = Duration(milliseconds: 150);
  static const _collapsedWidth = 48.0;
  static const _expandedWidth = 128.0;
  static const _height = 40.0;
  static const _minScale = 0.25;
  static const _maxScale = 2.0;
  static const _scaleStep = 0.1;

  // ---------- State ----------

  var _hovered = false;
  var _focused = false;

  bool get _expanded => _hovered || _focused;

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    return Focus(
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          key: const ValueKey('zoom-control'),
          duration: _animationDuration,
          curve: Curves.easeOutCubic,
          width: _expanded ? _expandedWidth : _collapsedWidth,
          height: _height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: _animationDuration,
                    opacity: _expanded ? 1 : 0,
                    child: const BContainer(child: SizedBox.expand()),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _action(
                  key: const ValueKey('zoom-out'),
                  label: 'Zoom out',
                  icon: LucideIcons.minus,
                  onPressed: () => _stepZoom(-_scaleStep),
                ),
              ),
              AnimatedAlign(
                duration: _animationDuration,
                curve: Curves.easeOutCubic,
                alignment: _expanded ? Alignment.center : Alignment.centerRight,
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) => _percentageButton(context),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _action(
                  key: const ValueKey('zoom-in'),
                  label: 'Zoom in',
                  icon: LucideIcons.plus,
                  onPressed: () => _stepZoom(_scaleStep),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _percentageButton(BuildContext context) {
    final theme = BTheme.of(context);
    final percentage = (widget.controller.scale * 100).round();
    return Semantics(
      label: 'Reset zoom to 100%',
      button: true,
      onTap: _resetZoom,
      excludeSemantics: true,
      child: TextButton(
        key: const ValueKey('zoom-reset'),
        onPressed: _resetZoom,
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(theme.colors.textMuted),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return theme.colors.surfacePressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return theme.colors.surfaceHover;
            }
            return Colors.transparent;
          }),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: theme.colors.focusRing, width: 2)
                : BorderSide.none,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: theme.geo.radiusMedium),
          ),
          textStyle: WidgetStatePropertyAll(
            theme.typo.body.copyWith(fontSize: 12),
          ),
          fixedSize: const WidgetStatePropertyAll(
            Size(_collapsedWidth, _height),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
        child: Text('$percentage%'),
      ),
    );
  }

  Widget _action({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return AnimatedOpacity(
      duration: _animationDuration,
      opacity: _expanded ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_expanded,
        child: ExcludeFocus(
          excluding: !_expanded,
          child: ExcludeSemantics(
            excluding: !_expanded,
            child: Tooltip(
              message: label,
              excludeFromSemantics: true,
              child: Semantics(
                label: label,
                button: true,
                onTap: onPressed,
                excludeSemantics: true,
                child: ToolbarButton(
                  key: key,
                  selected: false,
                  onPressed: onPressed,
                  child: Icon(icon, size: 15),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Actions ----------

  void _stepZoom(double delta) {
    final current = widget.controller.scale;
    if (delta > 0 && current >= _maxScale || delta < 0 && current <= _minScale) {
      return;
    }
    _setZoom((current + delta).clamp(_minScale, _maxScale));
  }

  void _resetZoom() => _setZoom(1);

  void _setZoom(double scale) {
    final delta = scale - widget.controller.scale;
    if (delta != 0) widget.controller.updateScalebyDelta(delta);
  }
}
