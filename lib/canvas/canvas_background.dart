import 'package:beyond/foundation/theme.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';

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
