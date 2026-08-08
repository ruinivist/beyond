import 'package:flutter/material.dart';

const smoothScrollDuration = Duration(milliseconds: 120);

class SmoothScrollController extends ScrollController {
  SmoothScrollController({super.debugLabel});

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SmoothScrollPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  double? _target;
  int _animation = 0;

  @override
  void pointerScroll(double delta) {
    if (delta == 0) {
      _target = null;
      super.pointerScroll(delta);
      return;
    }

    final target = ((_target ?? pixels) + delta)
        .clamp(minScrollExtent, maxScrollExtent)
        .toDouble();
    if (target == _target) return;

    _target = target;
    final animation = ++_animation;
    super
        .animateTo(
          target,
          duration: smoothScrollDuration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (_animation == animation) _target = null;
        });
  }
}
