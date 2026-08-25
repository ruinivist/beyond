import 'dart:io';
import 'dart:typed_data';

import 'package:beyond/canvas/attachment_store_base.dart';
import 'package:path_provider/path_provider.dart';

class PlatformAttachmentStore implements AttachmentStore {
  @override
  Future<void> write(String path, Uint8List bytes) async {
    final file = await _file(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List> read(String path) async =>
      (await _file(path)).readAsBytes();

  @override
  Future<Uint8List?> readIfExists(String path) async {
    final file = await _file(path);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  Future<File> _file(String path) async {
    final fileName = attachmentFileName(path);
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/attachments/$fileName');
  }
}
