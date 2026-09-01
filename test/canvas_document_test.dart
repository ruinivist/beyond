import 'dart:convert';
import 'dart:math' as math;

import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canvas documents round-trip mixed element data', () {
    const source =
        '## Authentication\n\n- [x] OAuth callback\n\n\$a^2 + b^2 = c^2\$';
    final document = CanvasDocument(
      background: CanvasBackgroundKind.plain,
      elements: [
        ArrowElementData(
          id: 'arrow-1',
          start: const Offset(10, 20),
          control: const Offset(40, 5),
          end: const Offset(80, 60),
        ),
        TextElementData(
          id: 'text-1',
          position: const Offset(-120, 200),
          width: 320,
          height: 180,
          markdown: source,
          rotation: math.pi * 3,
          style: const TextNodeStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            color: '#201C1A',
          ),
        ),
        PenElementData(
          id: 'pen-1',
          position: const Offset(-40, 30),
          size: const Size(180, 90),
          hitSlop: 6,
          color: 0xff000000,
          width: 3,
          points: const [
            PenPointData(Offset(6, 6), pressure: 0.4),
          ],
        ),
        CodeElementData(
          id: 'code-1',
          position: const Offset(100, 200),
          size: const Size(600, 400),
          language: CodeLanguage.dart,
          source: 'void main() {}',
        ),
        MediaElementData(
          id: 'media-1',
          position: const Offset(220, -80),
          width: 400,
          url: 'https://example.com/image.png',
        ),
        ShapeElementData(
          id: 'shape-1',
          kind: ShapeKind.ellipse,
          position: const Offset(300, 120),
          size: const Size(180, 100),
        ),
      ],
    );

    final encoded = jsonEncode(document.toJson());
    final restored = CanvasDocument.fromJson(jsonDecode(encoded));
    final elements = restored.elements;

    expect(restored.toJson()['version'], CanvasDocument.version);
    expect(restored.background, CanvasBackgroundKind.plain);
    expect(elements.map((element) => element.id), [
      'arrow-1',
      'text-1',
      'pen-1',
      'code-1',
      'media-1',
      'shape-1',
    ]);
    expect(elements[0], isA<ArrowElementData>());
    expect(elements[1], isA<TextElementData>());
    expect(elements[2], isA<PenElementData>());
    expect(elements[3], isA<CodeElementData>());
    expect(elements[4], isA<MediaElementData>());
    expect(elements[5], isA<ShapeElementData>());

    final node = elements[1] as TextElementData;
    expect(node.position, const Offset(-120, 200));
    expect(node.width, 320);
    expect(node.height, 180);
    expect(node.rotation, math.pi * 3);
    expect(node.markdown, source);
    expect(node.style.fontFamily, 'Inter');
    expect(node.style.fontSize, 20);
    expect(node.style.color, '#201C1A');

    final pen = elements[2] as PenElementData;
    expect(pen.size, const Size(180, 90));
    expect(pen.hitSlop, 6);
    expect(pen.points.single.pressure, 0.4);

    final code = elements[3] as CodeElementData;
    expect(code.position, const Offset(100, 200));
    expect(code.size, const Size(600, 400));
    expect(code.language, CodeLanguage.dart);
    expect(code.source, 'void main() {}');

    final media = elements[4] as MediaElementData;
    expect(media.position, const Offset(220, -80));
    expect(media.width, 400);
    expect(media.url, 'https://example.com/image.png');

    final shape = elements[5] as ShapeElementData;
    expect(shape.kind, ShapeKind.ellipse);
    expect(shape.position, const Offset(300, 120));
    expect(shape.size, const Size(180, 100));

    final arrow = elements[0] as ArrowElementData;
    expect(arrow.start, const Offset(10, 20));
    expect(arrow.control, const Offset(40, 5));
    expect(arrow.end, const Offset(80, 60));

    final snapshot = document.copy();
    expect(snapshot.elements, isNot(same(document.elements)));
    expect(
      (snapshot.elements[2] as PenElementData).points,
      isNot(same((document.elements[2] as PenElementData).points)),
    );
  });

  test('unknown document versions are rejected', () {
    expect(
      () => CanvasDocument.fromJson(_document(version: 1)),
      throwsA(isA<FormatException>()),
    );
  });

  test('shape kinds and minimum dimensions are validated', () {
    Map<String, Object?> shape({Object kind = 'diamond', double width = 32}) =>
        {
          'id': 'shape',
          'type': 'shape',
          'kind': kind,
          'position': {'x': 0.0, 'y': 0.0},
          'size': {'width': width, 'height': 32.0},
        };

    expect(
      () => CanvasDocument.fromJson(
        _document(elements: [shape(kind: 'triangle')]),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CanvasDocument.fromJson(
        _document(elements: [shape(width: 31)]),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('unknown document keys are rejected', () {
    final document = _document()..['extra'] = true;

    expect(
      () => CanvasDocument.fromJson(document),
      throwsA(isA<FormatException>()),
    );
  });

  test('unknown element keys are rejected', () {
    final document = _document(elements: [_encodedText()..['extra'] = true]);

    expect(
      () => CanvasDocument.fromJson(document),
      throwsA(isA<FormatException>()),
    );
  });

  test('unknown position keys are rejected', () {
    final document = _document(
      elements: [
        _encodedText(position: {'x': 0.0, 'y': 0.0, 'extra': true}),
      ],
    );

    expect(
      () => CanvasDocument.fromJson(document),
      throwsA(isA<FormatException>()),
    );
  });

  test('unknown style keys are rejected', () {
    final document = _document(
      elements: [
        _encodedText(
          style: {
            'fontFamily': 'Source Serif 4',
            'fontSize': 20.0,
            'color': '#201C1A',
            'extra': true,
          },
        ),
      ],
    );

    expect(
      () => CanvasDocument.fromJson(document),
      throwsA(isA<FormatException>()),
    );
  });

  test('duplicate IDs are rejected across element types', () {
    expect(
      () => CanvasDocument.fromJson(
        _document(
          elements: [
            _encodedText(id: 'same'),
            _encodedCode(id: 'same'),
          ],
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('non-finite text values are rejected', () {
    expect(
      () => CanvasDocument.fromJson(
        _document(
          elements: [
            _encodedText(position: {'x': double.infinity, 'y': 0}),
          ],
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CanvasDocument.fromJson(
        _document(elements: [_encodedText(width: double.nan)]),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CanvasDocument.fromJson(
        _document(elements: [_encodedText(height: double.nan)]),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CanvasDocument.fromJson(
        _document(elements: [_encodedText(fontSize: double.infinity)]),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CanvasDocument.fromJson(
        _document(elements: [_encodedText(rotation: double.infinity)]),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('text dimensions and styles are validated', () {
    expect(
      () => CanvasDocument.fromJson(
        _document(
          elements: [_encodedText(width: textNodeMinimumWidth - 1)],
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CanvasDocument.fromJson(
        _document(
          elements: [_encodedText(height: textNodeMinimumHeight - 1)],
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CanvasDocument.fromJson(
        _document(elements: [_encodedText(fontFamily: 'Arial')]),
      ),
      throwsA(isA<FormatException>()),
    );

    for (final color in ['#201c1a', '#21A', '#80201C1A', '201C1A']) {
      expect(
        () => CanvasDocument.fromJson(
          _document(elements: [_encodedText(color: color)]),
        ),
        throwsA(isA<FormatException>()),
        reason: color,
      );
    }
  });

  test('missing text height keeps automatic sizing', () {
    final node =
        CanvasDocument.fromJson(_document()).elements.single as TextElementData;

    expect(node.height, isNull);
    expect(node.toJson()['size'], isNot(contains('height')));
  });

  test('malformed non-text elements are rejected', () {
    final code = _encodedCode();
    expect(
      () => CanvasDocument.fromJson(
        _document(elements: [code..['language'] = 'unknown']),
      ),
      throwsA(isA<FormatException>()),
    );

    final pen = _encodedPen();
    expect(
      () => CanvasDocument.fromJson(
        _document(elements: [pen..['points'] = <Object?>[]]),
      ),
      throwsA(isA<FormatException>()),
    );

    final arrow = _encodedArrow();
    expect(
      () => CanvasDocument.fromJson(
        _document(
          elements: [
            arrow..['end'] = {'x': 1.0, 'y': 1.0},
          ],
        ),
      ),
      throwsA(isA<FormatException>()),
    );

    expect(
      () => CanvasDocument.fromJson(
        _document(
          elements: [
            {
              'id': 'media',
              'type': 'media',
              'position': {'x': 0.0, 'y': 0.0},
              'width': mediaNodeMinimumWidth - 1,
              'url': '',
            },
          ],
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, Object?> _document({
  int version = CanvasDocument.version,
  List<Map<String, Object?>>? elements,
}) {
  return {
    'version': version,
    'background': 'dotGrid',
    'elements': elements ?? [_encodedText()],
  };
}

Map<String, Object?> _encodedText({
  String id = 'text-1',
  Map<String, Object?> position = const {'x': 0.0, 'y': 0.0},
  Object width = textNodeDefaultWidth,
  Object? height,
  Object rotation = 0.0,
  String fontFamily = 'Source Serif 4',
  Object fontSize = textNodeDefaultFontSize,
  String color = '#201C1A',
  Map<String, Object?>? style,
}) {
  return {
    'id': id,
    'type': 'text',
    'position': position,
    'size': <String, Object?>{'width': width, 'height': ?height},
    'rotation': rotation,
    'markdown': '',
    'style':
        style ??
        {
          'fontFamily': fontFamily,
          'fontSize': fontSize,
          'color': color,
        },
  };
}

Map<String, Object?> _encodedCode({String id = 'code-1'}) => {
  'id': id,
  'type': 'code',
  'position': {'x': 0.0, 'y': 0.0},
  'size': {'width': 280.0, 'height': 240.0},
  'language': 'dart',
  'source': '',
};

Map<String, Object?> _encodedPen({String id = 'pen-1'}) => {
  'id': id,
  'type': 'pen',
  'position': {'x': 0.0, 'y': 0.0},
  'size': {'width': 10.0, 'height': 10.0},
  'hitSlop': 0.0,
  'color': 0,
  'width': 1.0,
  'points': [
    {'x': 0.0, 'y': 0.0, 'pressure': 0.0},
  ],
};

Map<String, Object?> _encodedArrow({String id = 'arrow-1'}) => {
  'id': id,
  'type': 'arrow',
  'start': {'x': 0.0, 'y': 0.0},
  'control': {'x': 2.0, 'y': 2.0},
  'end': {'x': 4.0, 'y': 0.0},
};
