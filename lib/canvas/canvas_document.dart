import 'dart:ui';

import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/canvas/tools/code_block/code_language.dart';

const textNodeDefaultWidth = 280.0;
const textNodeMinimumWidth = 160.0;
const textNodeMinimumHeight = 52.0;
const textNodeDefaultFontSize = 20.0;

const textNodeFontFamilies = <String>{
  'Source Serif 4',
  'Inter',
  'Roboto Mono',
};

const codeBlockMinimumSize = Size(280, 240);
const mediaNodeDefaultWidth = 400.0;
const mediaNodeMinimumWidth = 120.0;
const arrowMinimumLength = 4.0;

final _canonicalColor = RegExp(r'^#[0-9A-F]{6}$');

class CanvasDocument {
  const CanvasDocument({required this.background, required this.elements});

  factory CanvasDocument.fromJson(Object? json) {
    final value = _jsonObject(
      json,
      'document',
      allowedKeys: const {'version', 'background', 'elements'},
    );
    if (value['version'] is! int || value['version'] != version) {
      throw const FormatException('document.version must be 2');
    }

    final background = _backgroundFromJson(value['background']);
    final encodedElements = value['elements'];
    if (encodedElements is! List) {
      throw const FormatException('document.elements must be a list');
    }

    final elements = <CanvasElementData>[];
    final ids = <String>{};
    for (final encodedElement in encodedElements) {
      final element = CanvasElementData.fromJson(encodedElement);
      if (!ids.add(element.id)) {
        throw FormatException('Duplicate canvas element id: ${element.id}');
      }
      elements.add(element);
    }

    return CanvasDocument(background: background, elements: elements);
  }

  static const version = 2;

  final CanvasBackgroundKind background;
  final List<CanvasElementData> elements;

  Map<String, Object> toJson() => <String, Object>{
    'version': version,
    'background': background.name,
    'elements': elements.map((element) => element.toJson()).toList(),
  };

  CanvasDocument copy() => CanvasDocument(
    background: background,
    elements: elements.map((element) => element.copy()).toList(),
  );
}

sealed class CanvasElementData {
  const CanvasElementData(this.id);

  factory CanvasElementData.fromJson(Object? json) {
    final value = _jsonObject(
      json,
      'element',
      allowedKeys: const {
        'id',
        'type',
        'position',
        'size',
        'rotation',
        'markdown',
        'style',
        'language',
        'source',
        'url',
        'hitSlop',
        'color',
        'width',
        'points',
        'start',
        'control',
        'end',
      },
    );
    final type = value['type'];
    if (type is! String) {
      throw const FormatException('element.type must be a string');
    }
    return switch (type) {
      'text' => TextElementData.fromJson(value),
      'code' => CodeElementData.fromJson(value),
      'media' => MediaElementData.fromJson(value),
      'pen' => PenElementData.fromJson(value),
      'arrow' => ArrowElementData.fromJson(value),
      _ => throw FormatException('Unknown canvas element type: $type'),
    };
  }

  final String id;

  String get type;

  Map<String, Object> toJson();

  CanvasElementData copy({String? id});
}

class MediaElementData extends CanvasElementData {
  MediaElementData({
    required String id,
    required this.position,
    required this.width,
    required this.url,
  }) : super(id);

  factory MediaElementData.fromJson(Object? json) {
    final value = _jsonObject(
      json,
      'media element',
      allowedKeys: const {'id', 'type', 'position', 'width', 'url'},
    );
    final id = _requiredString(value, 'id', nonEmpty: true);
    if (value['type'] != 'media') {
      throw const FormatException('element.type must be media');
    }
    final width = _finiteNumber(value['width'], 'element.width');
    if (width < mediaNodeMinimumWidth) {
      throw const FormatException('element.width is below the minimum');
    }

    return MediaElementData(
      id: id,
      position: _offsetFromJson(value['position'], 'element.position'),
      width: width,
      url: _requiredString(value, 'url'),
    );
  }

  @override
  String get type => 'media';

  Offset position;
  double width;
  String url;

  @override
  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'type': type,
    'position': _offsetToJson(position),
    'width': width,
    'url': url,
  };

  @override
  MediaElementData copy({String? id}) => MediaElementData(
    id: id ?? this.id,
    position: position,
    width: width,
    url: url,
  );
}

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
    if (color is! String || !_canonicalColor.hasMatch(color)) {
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

class TextElementData extends CanvasElementData {
  TextElementData({
    required String id,
    required this.position,
    required this.width,
    required this.height,
    required this.markdown,
    required this.style,
    this.rotation = 0,
  }) : super(id);

  factory TextElementData.fromJson(Object? json) {
    final value = _jsonObject(
      json,
      'text element',
      allowedKeys: const {
        'id',
        'type',
        'position',
        'size',
        'rotation',
        'markdown',
        'style',
      },
    );
    final id = _requiredString(value, 'id', nonEmpty: true);
    if (value['type'] != 'text') {
      throw const FormatException('element.type must be text');
    }

    final position = _offsetFromJson(value['position'], 'element.position');
    final size = _textSizeFromJson(value['size'], 'element.size');
    if (size.width < textNodeMinimumWidth) {
      throw const FormatException('element.size.width is below the minimum');
    }
    if (size.height != null && size.height! < textNodeMinimumHeight) {
      throw const FormatException('element.size.height is below the minimum');
    }
    final rotation = _finiteNumber(value['rotation'], 'element.rotation');
    final markdown = value['markdown'];
    if (markdown is! String) {
      throw const FormatException('element.markdown must be a string');
    }

    return TextElementData(
      id: id,
      position: position,
      width: size.width,
      height: size.height,
      markdown: markdown,
      style: TextNodeStyle.fromJson(value['style']),
      rotation: rotation,
    );
  }

  @override
  String get type => 'text';

  Offset position;
  double width;
  double? height;
  String markdown;
  TextNodeStyle style;
  double rotation;

  @override
  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'type': type,
    'position': _offsetToJson(position),
    'size': <String, Object>{'width': width, 'height': ?height},
    'rotation': rotation,
    'markdown': markdown,
    'style': style.toJson(),
  };

  @override
  TextElementData copy({String? id}) => TextElementData(
    id: id ?? this.id,
    position: position,
    width: width,
    height: height,
    markdown: markdown,
    style: style.copy(),
    rotation: rotation,
  );
}

class CodeElementData extends CanvasElementData {
  CodeElementData({
    required String id,
    required this.position,
    required this.size,
    required this.language,
    required this.source,
  }) : super(id);

  factory CodeElementData.fromJson(Object? json) {
    final value = _jsonObject(
      json,
      'code element',
      allowedKeys: const {
        'id',
        'type',
        'position',
        'size',
        'language',
        'source',
      },
    );
    final id = _requiredString(value, 'id', nonEmpty: true);
    if (value['type'] != 'code') {
      throw const FormatException('element.type must be code');
    }
    final source = value['source'];
    if (source is! String) {
      throw const FormatException('element.source must be a string');
    }

    final size = _sizeFromJson(value['size'], 'element.size');
    if (size.width < codeBlockMinimumSize.width ||
        size.height < codeBlockMinimumSize.height) {
      throw const FormatException('element.size is below the minimum');
    }

    return CodeElementData(
      id: id,
      position: _offsetFromJson(value['position'], 'element.position'),
      size: size,
      language: _languageFromJson(value['language']),
      source: source,
    );
  }

  @override
  String get type => 'code';

  Offset position;
  Size size;
  CodeLanguage language;
  String source;

  @override
  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'type': type,
    'position': _offsetToJson(position),
    'size': _sizeToJson(size),
    'language': language.name,
    'source': source,
  };

  @override
  CodeElementData copy({String? id}) => CodeElementData(
    id: id ?? this.id,
    position: position,
    size: size,
    language: language,
    source: source,
  );
}

final class PenPointData {
  const PenPointData(this.position, {required this.pressure});

  final Offset position;
  final double pressure;
}

class PenElementData extends CanvasElementData {
  PenElementData({
    required String id,
    required this.position,
    required this.size,
    required this.hitSlop,
    required this.points,
    required this.color,
    required this.width,
  }) : super(id);

  factory PenElementData.fromJson(Object? json) {
    final value = _jsonObject(
      json,
      'pen element',
      allowedKeys: const {
        'id',
        'type',
        'position',
        'size',
        'hitSlop',
        'points',
        'color',
        'width',
      },
    );
    final id = _requiredString(value, 'id', nonEmpty: true);
    if (value['type'] != 'pen') {
      throw const FormatException('element.type must be pen');
    }
    final hitSlop = _finiteNumber(value['hitSlop'], 'element.hitSlop');
    if (hitSlop < 0) {
      throw const FormatException('element.hitSlop must be non-negative');
    }

    final color = value['color'];
    if (color is! int || color < 0 || color > 0xffffffff) {
      throw const FormatException('element.color must be an ARGB integer');
    }
    final width = _finiteNumber(value['width'], 'element.width');
    if (width <= 0) {
      throw const FormatException('element.width must be positive');
    }
    final encodedPoints = value['points'];
    if (encodedPoints is! List || encodedPoints.isEmpty) {
      throw const FormatException('element.points must not be empty');
    }
    final points = <PenPointData>[];
    for (var index = 0; index < encodedPoints.length; index++) {
      final point = _jsonObject(
        encodedPoints[index],
        'element.points[$index]',
        allowedKeys: const {'x', 'y', 'pressure'},
      );
      final pressure = _finiteNumber(
        point['pressure'],
        'element.points[$index].pressure',
      );
      if (pressure < 0 || pressure > 1) {
        throw FormatException(
          'element.points[$index].pressure must be between 0 and 1',
        );
      }
      points.add(
        PenPointData(
          Offset(
            _finiteNumber(point['x'], 'element.points[$index].x'),
            _finiteNumber(point['y'], 'element.points[$index].y'),
          ),
          pressure: pressure,
        ),
      );
    }

    return PenElementData(
      id: id,
      position: _offsetFromJson(value['position'], 'element.position'),
      size: _sizeFromJson(value['size'], 'element.size'),
      hitSlop: hitSlop,
      points: points,
      color: color,
      width: width,
    );
  }

  @override
  String get type => 'pen';

  Offset position;
  Size size;
  double hitSlop;
  List<PenPointData> points;
  int color;
  double width;

  @override
  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'type': type,
    'position': _offsetToJson(position),
    'size': _sizeToJson(size),
    'hitSlop': hitSlop,
    'color': color,
    'width': width,
    'points': [
      for (final point in points)
        <String, Object>{
          'x': point.position.dx,
          'y': point.position.dy,
          'pressure': point.pressure,
        },
    ],
  };

  @override
  PenElementData copy({String? id}) => PenElementData(
    id: id ?? this.id,
    position: position,
    size: size,
    hitSlop: hitSlop,
    points: List.of(points),
    color: color,
    width: width,
  );
}

class ArrowElementData extends CanvasElementData {
  ArrowElementData({
    required String id,
    required this.start,
    required this.control,
    required this.end,
  }) : super(id);

  factory ArrowElementData.fromJson(Object? json) {
    final value = _jsonObject(
      json,
      'arrow element',
      allowedKeys: const {'id', 'type', 'start', 'control', 'end'},
    );
    final id = _requiredString(value, 'id', nonEmpty: true);
    if (value['type'] != 'arrow') {
      throw const FormatException('element.type must be arrow');
    }
    final start = _offsetFromJson(value['start'], 'element.start');
    final control = _offsetFromJson(value['control'], 'element.control');
    final end = _offsetFromJson(value['end'], 'element.end');
    if ((end - start).distance < arrowMinimumLength) {
      throw const FormatException('element arrow is shorter than the minimum');
    }

    return ArrowElementData(
      id: id,
      start: start,
      control: control,
      end: end,
    );
  }

  @override
  String get type => 'arrow';

  Offset start;
  Offset control;
  Offset end;

  @override
  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'type': type,
    'start': _offsetToJson(start),
    'control': _offsetToJson(control),
    'end': _offsetToJson(end),
  };

  @override
  ArrowElementData copy({String? id}) => ArrowElementData(
    id: id ?? this.id,
    start: start,
    control: control,
    end: end,
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

String _requiredString(
  Map<String, Object?> value,
  String field, {
  bool nonEmpty = false,
}) {
  final result = value[field];
  if (result is! String || (nonEmpty && result.isEmpty)) {
    throw FormatException('$field must be a string');
  }
  return result;
}

double _finiteNumber(Object? value, String field) {
  if (value is! num) {
    throw FormatException('$field must be a finite number');
  }
  final result = value.toDouble();
  if (!result.isFinite) {
    throw FormatException('$field must be a finite number');
  }
  return result;
}

Offset _offsetFromJson(Object? value, String field) {
  final object = _jsonObject(value, field, allowedKeys: const {'x', 'y'});
  return Offset(
    _finiteNumber(object['x'], '$field.x'),
    _finiteNumber(object['y'], '$field.y'),
  );
}

Map<String, Object> _offsetToJson(Offset offset) => <String, Object>{
  'x': offset.dx,
  'y': offset.dy,
};

Size _sizeFromJson(Object? value, String field) {
  final object = _jsonObject(
    value,
    field,
    allowedKeys: const {'width', 'height'},
  );
  final width = _finiteNumber(object['width'], '$field.width');
  final height = _finiteNumber(object['height'], '$field.height');
  if (width <= 0 || height <= 0) {
    throw FormatException('$field dimensions must be positive');
  }
  return Size(width, height);
}

({double width, double? height}) _textSizeFromJson(
  Object? value,
  String field,
) {
  final object = _jsonObject(
    value,
    field,
    allowedKeys: const {'width', 'height'},
  );
  final width = _finiteNumber(object['width'], '$field.width');
  final height = object.containsKey('height')
      ? _finiteNumber(object['height'], '$field.height')
      : null;
  return (width: width, height: height);
}

Map<String, Object> _sizeToJson(Size size) => <String, Object>{
  'width': size.width,
  'height': size.height,
};

CodeLanguage _languageFromJson(Object? value) {
  if (value is! String) {
    throw const FormatException('element.language must be a string');
  }
  for (final language in CodeLanguage.values) {
    if (language.name == value) return language;
  }
  throw FormatException('Unknown code language: $value');
}

CanvasBackgroundKind _backgroundFromJson(Object? value) {
  if (value is! String) {
    throw const FormatException('document.background must be a string');
  }
  for (final background in CanvasBackgroundKind.values) {
    if (background.name == value) return background;
  }
  throw FormatException('Unknown canvas background: $value');
}
