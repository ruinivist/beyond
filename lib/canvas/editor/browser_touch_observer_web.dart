// Observes browser touch input even when accessibility consumes pointer events.
// Used by the canvas editor to reveal touch controls after physical releases.

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// ---------- Touch observation ----------

/// Observes physical touch sequences and returns listener cleanup.
/// Used by canvas controls when Flutter semantics consume pointer events.
VoidCallback observeBrowserTouch({required VoidCallback onStart, required VoidCallback onEnd}) {
  final pointers = <int>{};
  Timer? release;
  final listener = ((web.PointerEvent event) {
    if (event.pointerType != 'touch') return;
    release?.cancel();
    if (event.type == 'pointerdown') {
      pointers.add(event.pointerId);
      onStart();
    } else {
      pointers.remove(event.pointerId);
      if (pointers.isEmpty) {
        // Browser clicks and Flutter semantics callbacks follow pointerup.
        release = Timer(Duration.zero, onEnd);
      }
    }
  }).toJS;
  const events = ['pointerdown', 'pointerup', 'pointercancel'];
  for (final event in events) {
    web.document.addEventListener(event, listener, true.toJS);
  }
  return () {
    release?.cancel();
    for (final event in events) {
      web.document.removeEventListener(event, listener, true.toJS);
    }
  };
}
