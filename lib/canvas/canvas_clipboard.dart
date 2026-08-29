import 'dart:convert';

import 'package:beyond/canvas/canvas_document.dart';

const _format = 'beyond-canvas-clipboard';
final _formatMarker = RegExp(
  r'"format"\s*:\s*"beyond-canvas-clipboard"',
);

const canvasClipboardVersion = 2;

String encodeCanvasClipboard(Iterable<CanvasElementData> elements) =>
    jsonEncode(<String, Object>{
      'format': _format,
      'version': canvasClipboardVersion,
      'elements': elements.map((element) => element.toJson()).toList(),
    });

List<CanvasElementData>? decodeCanvasClipboard(String text) {
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    if (_formatMarker.hasMatch(text)) {
      throw const FormatException('Malformed Beyond clipboard payload');
    }
    return null;
  }
  if (decoded is! Map || decoded['format'] != _format) return null;
  if (decoded.keys.any(
        (key) => !{'format', 'version', 'elements'}.contains(key),
      ) ||
      decoded['version'] != canvasClipboardVersion ||
      decoded['elements'] is! List) {
    throw const FormatException('Malformed Beyond clipboard payload');
  }
  final elements = (decoded['elements'] as List)
      .map(CanvasElementData.fromJson)
      .toList();
  if (elements.isEmpty) {
    throw const FormatException('Clipboard elements must not be empty');
  }
  return elements;
}
