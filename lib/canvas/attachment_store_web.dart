import 'dart:js_interop';
import 'dart:typed_data';

import 'package:beyond/canvas/attachment_store_base.dart';
import 'package:web/web.dart';

class PlatformAttachmentStore implements AttachmentStore {
  @override
  Future<void> write(String path, Uint8List bytes) async {
    final file = await _file(path, create: true);
    final writable = await file.createWritable().toDart;
    await writable.write(bytes.toJS).toDart;
    await writable.close().toDart;
  }

  @override
  Future<Uint8List> read(String path) async {
    final file = await (await _file(path, create: false)).getFile().toDart;
    return (await file.arrayBuffer().toDart).toDart.asUint8List();
  }

  @override
  Future<Uint8List?> readIfExists(String path) async {
    try {
      final file = await (await _file(path, create: false)).getFile().toDart;
      return (await file.arrayBuffer().toDart).toDart.asUint8List();
    } catch (error) {
      if (error.isA<DOMException>()) {
        final exception = error as DOMException;
        if (exception.name == 'NotFoundError') return null;
      }
      rethrow;
    }
  }

  Future<FileSystemFileHandle> _file(
    String path, {
    required bool create,
  }) async {
    final fileName = attachmentFileName(path);
    final root = await window.navigator.storage.getDirectory().toDart;
    final attachments = await root
        .getDirectoryHandle(
          'attachments',
          FileSystemGetDirectoryOptions(create: create),
        )
        .toDart;
    return attachments
        .getFileHandle(
          fileName,
          FileSystemGetFileOptions(create: create),
        )
        .toDart;
  }
}
