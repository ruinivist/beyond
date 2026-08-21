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

  Future<FileSystemFileHandle> _file(
    String path, {
    required bool create,
  }) async {
    final root = await window.navigator.storage.getDirectory().toDart;
    final attachments = await root
        .getDirectoryHandle(
          'attachments',
          FileSystemGetDirectoryOptions(create: create),
        )
        .toDart;
    return attachments
        .getFileHandle(
          attachmentFileName(path),
          FileSystemGetFileOptions(create: create),
        )
        .toDart;
  }
}
