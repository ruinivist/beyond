import 'package:flutter/material.dart';

const textNodeDefaultWidth = 280.0;
const textNodeMinimumWidth = 160.0;
const textNodeMinimumHeight = 52.0;
const textNodeDefaultFontSize = 20.0;

const textNodeFontFamilies = <String>{
  'Source Serif 4',
  'Inter',
  'Roboto Mono',
};

final _canonicalColor = RegExp(r'^#[0-9A-F]{6}$');

class TextNodeStyle {
  const TextNodeStyle({
    required this.fontFamily,
    required this.fontSize,
    required this.color,
  });

  factory TextNodeStyle.fromJson(Object? json) {
    final value = _jsonObject(
      json,
      'style',
      allowedKeys: const {'fontFamily', 'fontSize', 'color'},
    );
    final fontFamily = value['fontFamily'];
    if (fontFamily is! String || !textNodeFontFamilies.contains(fontFamily)) {
      throw const FormatException('style.fontFamily is not supported');
    }

    final fontSize = _finiteNumber(value['fontSize'], 'style.fontSize');
    if (fontSize <= 0) {
      throw const FormatException('style.fontSize must be positive');
    }

    final color = value['color'];
    if (color is! String ||
        color.length != 7 ||
        !_canonicalColor.hasMatch(color)) {
      throw const FormatException('style.color must be uppercase #RRGGBB');
    }

    return TextNodeStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      color: color,
    );
  }

  final String fontFamily;
  final double fontSize;
  final String color;

  TextNodeStyle copyWith({
    String? fontFamily,
    double? fontSize,
    String? color,
  }) {
    return TextNodeStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
    );
  }

  TextNodeStyle copy() => copyWith();

  Map<String, Object> toJson() => <String, Object>{
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'color': color,
  };
}

class TextNodeData {
  TextNodeData({
    required this.id,
    required this.position,
    required this.width,
    required this.height,
    required this.markdown,
    required this.style,
  });

  factory TextNodeData.fromJson(Object? json) {
    final value = _jsonObject(
      json,
      'text node',
      allowedKeys: const {
        'id',
        'type',
        'position',
        'width',
        'height',
        'markdown',
        'style',
      },
    );

    final id = value['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('node.id must be a non-empty string');
    }
    if (value['type'] != 'text') {
      throw const FormatException('node.type must be text');
    }

    final position = _jsonObject(
      value['position'],
      'node.position',
      allowedKeys: const {'x', 'y'},
    );
    final x = _finiteNumber(position['x'], 'node.position.x');
    final y = _finiteNumber(position['y'], 'node.position.y');
    final width = _finiteNumber(value['width'], 'node.width');
    if (width < textNodeMinimumWidth) {
      throw const FormatException('node.width must be at least 160.0');
    }
    final encodedHeight = value['height'];
    final height = encodedHeight == null
        ? null
        : _finiteNumber(encodedHeight, 'node.height');
    if (height != null && height < textNodeMinimumHeight) {
      throw const FormatException('node.height must be at least 52.0');
    }

    final markdown = value['markdown'];
    if (markdown is! String) {
      throw const FormatException('node.markdown must be a string');
    }

    return TextNodeData(
      id: id,
      position: Offset(x, y),
      width: width,
      height: height,
      markdown: markdown,
      style: TextNodeStyle.fromJson(value['style']),
    );
  }

  final String id;
  Offset position;
  double width;
  double? height;
  String markdown;
  TextNodeStyle style;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'type': 'text',
    'position': <String, double>{
      'x': position.dx,
      'y': position.dy,
    },
    'width': width,
    'height': ?height,
    'markdown': markdown,
    'style': style.toJson(),
  };

  TextNodeData copy() => TextNodeData(
    id: id,
    position: position,
    width: width,
    height: height,
    markdown: markdown,
    style: style.copy(),
  );
}

class CanvasDocument {
  const CanvasDocument({required this.nodes});

  factory CanvasDocument.fromJson(Object? json) {
    final value = _jsonObject(
      json,
      'document',
      allowedKeys: const {'version', 'nodes'},
    );
    if (value['version'] is! int || value['version'] != version) {
      throw const FormatException('document.version must be 1');
    }

    final encodedNodes = value['nodes'];
    if (encodedNodes is! List) {
      throw const FormatException('document.nodes must be a list');
    }

    final nodes = <TextNodeData>[];
    for (final encodedNode in encodedNodes) {
      nodes.add(TextNodeData.fromJson(encodedNode));
    }

    final ids = <String>{};
    for (final node in nodes) {
      if (!ids.add(node.id)) {
        throw FormatException('Duplicate text node id: ${node.id}');
      }
    }

    return CanvasDocument(nodes: nodes);
  }

  static const version = 1;

  final List<TextNodeData> nodes;

  Map<String, Object> toJson() => <String, Object>{
    'version': version,
    'nodes': nodes.map((node) => node.toJson()).toList(),
  };

  CanvasDocument copy() => CanvasDocument(
    nodes: nodes.map((node) => node.copy()).toList(),
  );
}

Map<String, Object?> _jsonObject(
  Object? value,
  String field, {
  required Set<String> allowedKeys,
}) {
  if (value is! Map) {
    throw FormatException('$field must be an object');
  }

  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$field must have string keys');
    }
    final key = entry.key as String;
    if (!allowedKeys.contains(key)) {
      throw FormatException('$field has unknown key: $key');
    }
    result[key] = entry.value;
  }
  return result;
}

double _finiteNumber(Object? value, String field) {
  if (value is! num || !value.isFinite) {
    throw FormatException('$field must be a finite number');
  }
  return value.toDouble();
}
