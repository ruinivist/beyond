// Supplies the native counterpart of the browser touch observer.
// Used by the canvas editor, whose native touch input comes from Flutter.

import 'package:flutter/foundation.dart';

// ---------- Touch observation ----------

VoidCallback observeBrowserTouch({required VoidCallback onStart, required VoidCallback onEnd}) => () {};
