import 'dart:typed_data';

const int attachmentMaximumBytes = 10 * 1024 * 1024;

abstract interface class AttachmentStore {
  Future<void> write(String path, Uint8List bytes);

  Future<Uint8List> read(String path);

  Future<Uint8List?> readIfExists(String path);
}

final attachmentPathPattern = RegExp(
  r'^attachments/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(?:png|jpg|gif|webp)$',
);

String attachmentFileName(String path) {
  if (!attachmentPathPattern.hasMatch(path)) {
    throw const FormatException('Invalid attachment path');
  }
  return path.substring('attachments/'.length);
}
