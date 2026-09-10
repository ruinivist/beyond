// Defines the available canvas backgrounds and their grid delegates.
// Used by document settings and infinite-canvas rendering.

import 'package:beyond/foundation/theme.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';

// ---------- Backgrounds ----------

/// Identifies and builds the backgrounds available to canvas documents.
/// Used by document serialization, settings, and grid rendering.
enum CanvasBackgroundKind {
  dotGrid,
  plain;

  CanvasBackground build(BColors colors) => switch (this) {
    CanvasBackgroundKind.dotGrid => DotGridBackground(
      dotColor: colors.canvasGrid,
      backgroundColor: colors.canvasBackground,
    ),
    CanvasBackgroundKind.plain => SingleColorBackground(
      colors.canvasBackground,
    ),
  };
}
