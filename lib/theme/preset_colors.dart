// Provides the named color presets offered by editing controls.
// Used by text and drawing tool settings.

import 'package:flutter/material.dart';

// ---------- Presets ----------
const presetColors = <({String label, Color color})>[
  (label: 'Black', color: Color(0xff2b2725)),
  (label: 'Gray', color: Color.fromARGB(255, 116, 109, 106)),
  (label: 'Red', color: Color(0xffd85b5b)),
  (label: 'Orange', color: Color(0xffdf824d)),
  (label: 'Yellow', color: Color.fromARGB(255, 219, 175, 65)),
  (label: 'Green', color: Color(0xff68a36c)),
  (label: 'Blue', color: Color(0xff5c86d6)),
  (label: 'Purple', color: Color(0xff9674d4)),
  (label: 'Pink', color: Color(0xffd26598)),
];
