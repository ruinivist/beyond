import 'dart:convert';
import 'dart:typed_data';

import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_project.dart';
import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mixed projects round-trip with deterministic attachments', () async {
    final document = _document(
      markdown: '''
![first](attachments/00000000-0000-4000-8000-000000000000.png)
![second](attachments/00000001-0000-4000-8000-000000000000.png)
''',
    );
    final first = _pngBytes;
    final second = Uint8List.fromList(_pngBytes);
    final store = _MemoryAttachmentStore({
      _path(0): first,
      _path(1): second,
    });

    final encoded = await encodeCanvasProject(document, store);
    final root = jsonDecode(utf8.decode(encoded)) as Map<String, dynamic>;
    final attachmentMap = root['attachments'] as Map<String, dynamic>;
    expect(attachmentMap.keys, [_path(0), _path(1)]);

    final project = await decodeCanvasProject(encoded);
    expect(project.document.toJson(), document.toJson());
    expect(project.attachments[_path(0)], first);
    expect(project.attachments[_path(1)], second);
  });

  test('local image discovery uses the Markdown AST', () {
    final paths = canvasAttachmentPaths(
      _document(
        markdown: '''
attachments/00000000-0000-4000-8000-000000000000.png

```markdown
![fenced](attachments/00000001-0000-4000-8000-000000000000.png)
```

![local](attachments/00000000-0000-4000-8000-000000000000.png)
![duplicate](attachments/00000000-0000-4000-8000-000000000000.png)
![external](https://example.com/image.png)
![invalid](attachments/not-a-uuid.png)
![broken](attachments/00000001-0000-4000-8000-000000000000.png
''',
      ),
    );

    expect(paths, {_path(0)});
  });

  test('repeated references are read and encoded once', () async {
    final document = _document(
      markdown: '![one](${_path(0)})\n![two](${_path(0)})',
    );
    final store = _MemoryAttachmentStore({_path(0): _pngBytes});

    await encodeCanvasProject(document, store);

    expect(store.reads, 1);
  });

  test('missing stored attachments fail export', () async {
    await expectLater(
      encodeCanvasProject(
        _document(markdown: '![missing](${_path(0)})'),
        _MemoryAttachmentStore(),
      ),
      throwsStateError,
    );
  });

  test('root, format, and document validation is strict', () async {
    final unknownRootKey = _validProjectJson()..['extra'] = true;
    await expectLater(_decodeJson(unknownRootKey), throwsFormatException);

    final wrongFormat = _validProjectJson()..['format'] = 'other';
    await expectLater(_decodeJson(wrongFormat), throwsFormatException);

    final wrongVersion = _validProjectJson()
      ..['document'] = {
        'version': 1,
        'background': 'dotGrid',
        'elements': <Object?>[],
      };
    await expectLater(_decodeJson(wrongVersion), throwsFormatException);
  });

  test('invalid paths, base64, image data, and attachment sets fail', () async {
    final invalidPath = _validProjectJson()
      ..['attachments'] = {'attachments/not-a-uuid.png': 'AAAA'};
    await expectLater(_decodeJson(invalidPath), throwsFormatException);

    final invalidBase64 = _validProjectJson()
      ..['attachments'] = {_path(0): 'not base64'};
    await expectLater(_decodeJson(invalidBase64), throwsFormatException);

    final malformedImage = _validProjectJson()
      ..['attachments'] = {
        _path(0): base64Encode(<int>[1, 2, 3]),
      };
    await expectLater(_decodeJson(malformedImage), throwsFormatException);

    final missingAttachment = _validProjectJson()
      ..['document'] = _document(markdown: '![missing](${_path(0)})').toJson();
    await expectLater(_decodeJson(missingAttachment), throwsFormatException);

    final extraAttachment = _validProjectJson()
      ..['attachments'] = {_path(0): base64Encode(_pngBytes)};
    await expectLater(_decodeJson(extraAttachment), throwsFormatException);
  });

  test('attachment and project size limits reject only overages', () async {
    expect(
      () => validateCanvasProjectSize(canvasProjectMaximumBytes),
      returnsNormally,
    );
    expect(
      () => validateCanvasProjectSize(canvasProjectMaximumBytes + 1),
      throwsFormatException,
    );

    final document = _document(markdown: '![image](${_path(0)})');
    final atLimit = _MemoryAttachmentStore({
      _path(0): Uint8List(attachmentMaximumBytes),
    });
    await encodeCanvasProject(document, atLimit);

    final overLimit = _MemoryAttachmentStore({
      _path(0): Uint8List(attachmentMaximumBytes + 1),
    });
    await expectLater(
      encodeCanvasProject(document, overLimit),
      throwsFormatException,
    );
  });
}

Future<CanvasProject> _decodeJson(Map<String, Object?> value) =>
    decodeCanvasProject(Uint8List.fromList(utf8.encode(jsonEncode(value))));

CanvasDocument _document({required String markdown}) => CanvasDocument(
  background: CanvasBackgroundKind.plain,
  elements: [
    TextElementData(
      id: 'text-1',
      position: const Offset(10, 20),
      width: 280,
      height: null,
      markdown: markdown,
      style: const TextNodeStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        color: '#201C1A',
      ),
    ),
    CodeElementData(
      id: 'code-1',
      position: const Offset(40, 50),
      size: const Size(280, 240),
      language: CodeLanguage.dart,
      source: 'void main() {}',
    ),
    PenElementData(
      id: 'pen-1',
      position: Offset.zero,
      size: const Size(10, 10),
      hitSlop: 0,
      color: 0xff000000,
      width: 1,
      points: const [PenPointData(Offset.zero, pressure: 0)],
    ),
    ArrowElementData(
      id: 'arrow-1',
      start: Offset.zero,
      control: const Offset(2, 2),
      end: const Offset(4, 0),
    ),
  ],
);

Map<String, Object?> _validProjectJson() => {
  'format': 'beyond-canvas',
  'document': _document(markdown: '').toJson(),
  'attachments': <String, Object?>{},
};

String _path(int index) =>
    'attachments/0000000$index-0000-4000-8000-000000000000.png';

final _pngBytes = Uint8List.fromList(
  base64Decode(
    [
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A',
      'AQUBAScY42YAAAAASUVORK5CYII=',
    ].join(),
  ),
);

class _MemoryAttachmentStore implements AttachmentStore {
  _MemoryAttachmentStore([Map<String, Uint8List>? initial])
    : files = {...?initial};

  final Map<String, Uint8List> files;
  int reads = 0;

  @override
  Future<Uint8List> read(String path) async {
    reads++;
    final bytes = files[path];
    if (bytes == null) throw StateError('Missing attachment: $path');
    return bytes;
  }

  @override
  Future<Uint8List?> readIfExists(String path) async => files[path];

  @override
  Future<void> write(String path, Uint8List bytes) async {
    files[path] = bytes;
  }
}
