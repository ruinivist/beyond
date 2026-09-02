import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:super_clipboard/super_clipboard.dart';

const _format = 'beyond-canvas-clipboard';
final _formatMarker = RegExp(
  r'"format"\s*:\s*"beyond-canvas-clipboard"',
);

const canvasClipboardVersion = 2;

typedef ClipboardImage = ({Uint8List bytes, String extension});
typedef CanvasClipboardSnapshot = ({String? text, ClipboardImage? image});

const _imageFormats = <FileFormat, String>{
  Formats.png: 'png',
  Formats.jpeg: 'jpg',
  Formats.gif: 'gif',
  Formats.webp: 'webp',
};

Future<CanvasClipboardSnapshot> readCanvasClipboard(
  ClipboardReader reader,
) async {
  ClipboardImage? image;
  final formats = reader.getFormats(_imageFormats.keys.toList());
  if (formats.isNotEmpty) {
    final format = formats.first as FileFormat;
    final bytes = await _readClipboardFile(reader, format);
    if (bytes != null) {
      image = (bytes: bytes, extension: _imageFormats[format]!);
    }
  }
  final text = reader.canProvide(Formats.plainText)
      ? await reader.readValue(Formats.plainText)
      : null;
  return (text: text, image: image);
}

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

Future<Uint8List?> _readClipboardFile(
  ClipboardReader reader,
  FileFormat format,
) {
  final result = Completer<Uint8List?>();
  final progress = reader.getFile(
    format,
    (file) async {
      try {
        if ((file.fileSize ?? 0) > attachmentMaximumBytes) {
          throw const FormatException('Image exceeds 10 MiB');
        }
        final bytes = await file.readAll();
        if (!result.isCompleted) result.complete(bytes);
      } on Object catch (error, stackTrace) {
        if (!result.isCompleted) result.completeError(error, stackTrace);
      }
    },
    onError: (error) {
      if (!result.isCompleted) result.completeError(error);
    },
  );
  if (progress == null) result.complete(null);
  return result.future;
}
