import 'dart:convert';
import 'dart:math' as math;

import 'package:beyond/canvas/tools/text/text_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canvas documents round-trip text node data', () {
    const source =
        '## Authentication\n\n- [x] OAuth callback\n\n\$a^2 + b^2 = c^2\$';
    final document = CanvasDocument(
      nodes: [
        TextNodeData(
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
      ],
    );

    final encoded = jsonEncode(document.toJson());
    final restored = CanvasDocument.fromJson(jsonDecode(encoded));
    final node = restored.nodes.single;

    expect(restored.toJson()['version'], CanvasDocument.version);
    expect(node.id, 'text-1');
    expect(node.position, const Offset(-120, 200));
    expect(node.width, 320);
    expect(node.height, 180);
    expect(node.rotation, math.pi * 3);
    expect(document.copy().nodes.single.height, 180);
    expect(document.copy().nodes.single.rotation, math.pi * 3);
    expect(node.markdown, source);
    expect(node.style.fontFamily, 'Inter');
    expect(node.style.fontSize, 20);
    expect(node.style.color, '#201C1A');
  });

  test('unknown document versions are rejected', () {
    expect(
      () => CanvasDocument.fromJson(_document(version: 2)),
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

  test('unknown node keys are rejected', () {
    final document = _document(nodes: [_encodedNode()..['extra'] = true]);

    expect(
      () => CanvasDocument.fromJson(document),
      throwsA(isA<FormatException>()),
    );
  });

  test('unknown position keys are rejected', () {
    final document = _document(
      position: {'x': 0.0, 'y': 0.0, 'extra': true},
    );

    expect(
      () => CanvasDocument.fromJson(document),
      throwsA(isA<FormatException>()),
    );
  });

  test('unknown style keys are rejected', () {
    final document = _document(
      style: {
        'fontFamily': 'Source Serif 4',
        'fontSize': 20.0,
        'color': '#201C1A',
        'extra': true,
      },
    );

    expect(
      () => CanvasDocument.fromJson(document),
      throwsA(isA<FormatException>()),
    );
  });

  test('duplicate text node IDs are rejected', () {
    final document = _document(
      nodes: [
        _encodedNode(id: 'same'),
        _encodedNode(id: 'same'),
      ],
    );

    expect(
      () => CanvasDocument.fromJson(document),
      throwsA(isA<FormatException>()),
    );
  });

  test('non-finite geometry and font size are rejected', () {
    expect(
      () => CanvasDocument.fromJson(
        _document(position: {'x': double.infinity, 'y': 0}),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CanvasDocument.fromJson(_document(width: double.nan)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CanvasDocument.fromJson(_document(height: double.nan)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CanvasDocument.fromJson(_document(fontSize: double.infinity)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => CanvasDocument.fromJson(_document(rotation: double.infinity)),
      throwsA(isA<FormatException>()),
    );
  });

  test('width below the minimum is rejected', () {
    expect(
      () => CanvasDocument.fromJson(
        _document(width: textNodeMinimumWidth - 1),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('height below the minimum is rejected', () {
    expect(
      () => CanvasDocument.fromJson(
        _document(height: textNodeMinimumHeight - 1),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('missing height keeps automatic sizing', () {
    final node = CanvasDocument.fromJson(_document()).nodes.single;

    expect(node.height, isNull);
    expect(node.toJson(), isNot(contains('height')));
  });

  test('unknown font families are rejected', () {
    expect(
      () => CanvasDocument.fromJson(_document(fontFamily: 'Arial')),
      throwsA(isA<FormatException>()),
    );
  });

  test('non-canonical colors are rejected', () {
    for (final color in ['#201c1a', '#21A', '#80201C1A', '201C1A']) {
      expect(
        () => CanvasDocument.fromJson(_document(color: color)),
        throwsA(isA<FormatException>()),
        reason: color,
      );
    }
  });
}

Map<String, Object?> _document({
  int version = CanvasDocument.version,
  List<Map<String, Object?>>? nodes,
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
    'version': version,
    'nodes':
        nodes ??
        [
          _encodedNode(
            position: position,
            width: width,
            height: height,
            rotation: rotation,
            fontFamily: fontFamily,
            fontSize: fontSize,
            color: color,
            style: style,
          ),
        ],
  };
}

Map<String, Object?> _encodedNode({
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
    'width': width,
    'height': ?height,
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
