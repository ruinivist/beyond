import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

abstract interface class CanvasProjectFiles {
  Future<Uint8List?> open();

  Future<bool> save(Uint8List bytes);
}

CanvasProjectFiles createCanvasProjectFiles() => _PlatformCanvasProjectFiles();

final class _PlatformCanvasProjectFiles implements CanvasProjectFiles {
  @override
  Future<Uint8List?> open() async => (await openFile())?.readAsBytes();

  @override
  Future<bool> save(Uint8List bytes) async {
    final location = await getSaveLocation(
      suggestedName: 'canvas.beyond.json',
    );
    if (location == null) return false;
    await XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: 'canvas.beyond.json',
    ).saveTo(location.path);
    return true;
  }
}
