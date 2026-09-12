// Defines reusable layout dimensions and component sizes.
// Used across application themes and reusable UI components.

import 'package:flutter/material.dart';

abstract final class BSizes {
  static const defaultTextButtonSize = Size(160, 36);
  static const defaultIconSize = 18.0;
  static const defaultIconButtonSize = Size.square(40);
}

extension BSizeCoordinates on Size {
  double get x => width;
  double get y => height;
}
