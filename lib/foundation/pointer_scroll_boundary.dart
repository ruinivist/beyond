import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class PointerScrollBoundary extends StatelessWidget {
  const PointerScrollBoundary({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          (event) => (event as PointerScrollEvent).respond(
            allowPlatformDefault: false,
          ),
        );
      },
      child: child,
    );
  }
}
