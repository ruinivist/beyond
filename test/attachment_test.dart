import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/canvas/tools/text/text_node.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pasted image is committed before its short reference is inserted',
    () async {
      final store = _MemoryAttachmentStore();
      final model = _model('before after')
        ..controller.selection = const TextSelection(
          baseOffset: 7,
          extentOffset: 12,
        );
      final bytes = Uint8List.fromList(<int>[1, 2, 3]);

      await model.insertPastedImage(bytes, 'png', store);

      final path = store.files.keys.single;
      expect(attachmentPathPattern.hasMatch(path), isTrue);
      expect(store.files[path], bytes);
      expect(model.node.markdown, 'before ![pasted image]($path)');
      expect(model.node.markdown, isNot(contains('base64')));
    },
  );

  test('oversized and failed image writes leave markdown unchanged', () async {
    final model = _model('unchanged');

    await expectLater(
      model.insertPastedImage(
        Uint8List(pastedImageMaximumBytes + 1),
        'png',
        _MemoryAttachmentStore(),
      ),
      throwsFormatException,
    );
    expect(model.node.markdown, 'unchanged');

    await expectLater(
      model.insertPastedImage(
        Uint8List.fromList(<int>[1]),
        'png',
        _MemoryAttachmentStore(failWrites: true),
      ),
      throwsStateError,
    );
    expect(model.node.markdown, 'unchanged');
  });

  test('plain text paste replaces the current selection', () {
    final model = _model('before after')
      ..controller.selection = const TextSelection(
        baseOffset: 7,
        extentOffset: 12,
      )
      ..insertPastedText('text');

    expect(model.node.markdown, 'before text');
    expect(
      model.controller.selection,
      const TextSelection.collapsed(offset: 11),
    );
  });

  test('attachment paths reject traversal and unsupported sources', () {
    for (final path in <String>[
      '../attachments/123.png',
      'attachments/not-a-uuid.png',
      'attachments/00000000-0000-4000-8000-000000000000.svg',
      'file:///attachments/00000000-0000-4000-8000-000000000000.png',
    ]) {
      expect(() => attachmentFileName(path), throwsFormatException);
    }
  });

  test('web attachment bytes survive a new store instance', () async {
    if (!kIsWeb) return;
    const path = 'attachments/00000000-0000-4000-8000-000000000000.webp';
    final bytes = Uint8List.fromList(<int>[4, 5, 6]);

    await createAttachmentStore().write(path, bytes);

    expect(await createAttachmentStore().read(path), bytes);
  });
}

TextBlockModel _model(String markdown) => TextBlockModel(
  TextNodeData(
    id: 'text',
    position: Offset.zero,
    width: textNodeDefaultWidth,
    height: null,
    markdown: markdown,
    style: const TextNodeStyle(
      fontFamily: 'Inter',
      fontSize: textNodeDefaultFontSize,
      color: '#201C1A',
    ),
  ),
);

class _MemoryAttachmentStore implements AttachmentStore {
  _MemoryAttachmentStore({this.failWrites = false});

  final bool failWrites;
  final files = <String, Uint8List>{};

  @override
  Future<Uint8List> read(String path) async => files[path]!;

  @override
  Future<void> write(String path, Uint8List bytes) async {
    if (failWrites) throw StateError('write failed');
    files[path] = bytes;
  }
}
