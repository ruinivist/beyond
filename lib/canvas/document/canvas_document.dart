// Defines the persisted canvas document schema, element data, and validation.
// Used by the editor, storage, clipboard, and project import/export flows.

import 'dart:ui';

import 'package:beyond/canvas/editor/canvas_background.dart';
import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:json_annotation/json_annotation.dart';

part 'canvas_document.g.dart';
part 'json_serialisation.dart';

// ---------- Constants ----------

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
const mediaNodeDefaultWidth = 480.0;
const mediaNodeMinimumWidth = 120.0;
const arrowMinimumLength = 4.0;
const shapeMinimumSize = Size.square(32);

// ---------- Types ----------

/// Identifies the geometry rendered by a shape element.
/// Used by shape tools, models, and document serialization.
enum ShapeKind {
  rectangle,
  roundedRectangle,
  ellipse,
  diamond,
  triangle,
  hexagon,
}

// ---------- Document models ----------

/// Holds the background and ordered elements of a persisted canvas.
/// Used as the shared document value across editing, storage, and transfer.
@_strictJson
class CanvasDocument {
  // ---------- Construction ----------

  const CanvasDocument({required this.background, required this.elements}) : schemaVersion = version;

  const CanvasDocument._json({
    required this.schemaVersion,
    required this.background,
    required this.elements,
  });

  factory CanvasDocument.fromJson(Object? json) {
    final document = _decode(json, 'document', _$CanvasDocumentFromJson);
    if (document.schemaVersion != version) {
      throw const FormatException('document.version must be 2');
    }
    final ids = <String>{};
    for (final element in document.elements) {
      if (!ids.add(element.id)) {
        throw FormatException('Duplicate canvas element id: ${element.id}');
      }
    }
    return document;
  }

  // ---------- Constants ----------

  static const version = 2;

  // ---------- State ----------

  @JsonKey(name: 'version', fromJson: _jsonInt)
  final int schemaVersion;
  final CanvasBackgroundKind background;
  final List<CanvasElementData> elements;

  // ---------- Serialization ----------

  Map<String, Object?> toJson() => _$CanvasDocumentToJson(this);

  // ---------- Copying ----------

  CanvasDocument copy() => CanvasDocument(
    background: background,
    elements: elements.map((element) => element.copy()).toList(),
  );
}

/// Defines the shared identity and serialization contract for canvas elements.
/// Used by document parsing and every concrete editor element model.
sealed class CanvasElementData {
  // ---------- Construction ----------

  CanvasElementData(this.id, this.type);

  factory CanvasElementData.fromJson(Object? json) {
    final value = _jsonMap(json, 'element');
    return switch (value['type']) {
      'text' => TextElementData.fromJson(value),
      'code' => CodeElementData.fromJson(value),
      'media' => MediaElementData.fromJson(value),
      'shape' => ShapeElementData.fromJson(value),
      'pen' => PenElementData.fromJson(value),
      'arrow' => ArrowElementData.fromJson(value),
      final type when type is String => throw FormatException(
        'Unknown canvas element type: $type',
      ),
      _ => throw const FormatException('element.type must be a string'),
    };
  }

  // ---------- State ----------

  final String id;
  final String type;

  // ---------- Interface ----------

  Map<String, Object?> toJson();

  CanvasElementData copy({String? id});

  // ---------- Validation ----------

  void validateType(String expected) {
    if (id.isEmpty) throw const FormatException('element.id must not be empty');
    if (type != expected) {
      throw FormatException('element.type must be $expected');
    }
  }
}

/// Stores the editable geometry and appearance of a shape element.
/// Used by the shape tool and its canvas model.
@_strictJson
class ShapeElementData extends CanvasElementData {
  // ---------- Construction ----------

  ShapeElementData({
    required String id,
    required this.kind,
    required this.position,
    required this.size,
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
  }) : super(id, 'shape');

  ShapeElementData._json({
    required String id,
    required String type,
    required this.kind,
    required this.position,
    required this.size,
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
  }) : super(id, type);

  factory ShapeElementData.fromJson(Object? json) {
    final shape = _decode(json, 'shape element', _$ShapeElementDataFromJson)..validateType('shape');
    if (shape.size.width < shapeMinimumSize.width || shape.size.height < shapeMinimumSize.height) {
      throw const FormatException('element.size is below the shape minimum');
    }
    _validateArgb(shape.strokeColor, 'element.strokeColor');
    if (shape.fillColor case final color?) {
      _validateArgb(color, 'element.fillColor');
    }
    _validatePositive(shape.strokeWidth, 'element.strokeWidth');
    return shape;
  }

  // ---------- State ----------

  ShapeKind kind;
  @_OffsetConverter()
  Offset position;
  @_SizeConverter()
  Size size;
  @JsonKey(fromJson: _jsonInt)
  int strokeColor;
  @JsonKey(fromJson: _nullableJsonInt)
  int? fillColor;
  double strokeWidth;

  // ---------- Serialization ----------

  @override
  Map<String, Object?> toJson() => _$ShapeElementDataToJson(this);

  // ---------- Copying ----------

  @override
  ShapeElementData copy({String? id}) => ShapeElementData(
    id: id ?? this.id,
    kind: kind,
    position: position,
    size: size,
    strokeColor: strokeColor,
    fillColor: fillColor,
    strokeWidth: strokeWidth,
  );
}

/// Stores the position, width, and source URL of a media element.
/// Used by media nodes and document attachment handling.
@_strictJson
class MediaElementData extends CanvasElementData {
  // ---------- Construction ----------

  MediaElementData({
    required String id,
    required this.position,
    required this.width,
    required this.url,
  }) : super(id, 'media');

  MediaElementData._json({
    required String id,
    required String type,
    required this.position,
    required this.width,
    required this.url,
  }) : super(id, type);

  factory MediaElementData.fromJson(Object? json) {
    final media = _decode(json, 'media element', _$MediaElementDataFromJson)..validateType('media');
    _validateFinite(media.width, 'element.width');
    if (media.width < mediaNodeMinimumWidth) {
      throw const FormatException('element.width is below the minimum');
    }
    return media;
  }

  // ---------- State ----------

  @_OffsetConverter()
  Offset position;
  double width;
  String url;

  // ---------- Serialization ----------

  @override
  Map<String, Object?> toJson() => _$MediaElementDataToJson(this);

  // ---------- Copying ----------

  @override
  MediaElementData copy({String? id}) => MediaElementData(
    id: id ?? this.id,
    position: position,
    width: width,
    url: url,
  );
}

/// Stores the font and color settings applied to a text element.
/// Used by text element data and the text editor model.
@_strictJson
class TextNodeStyle {
  // ---------- Construction ----------

  const TextNodeStyle({
    required this.fontFamily,
    required this.fontSize,
    required this.color,
  });

  const TextNodeStyle._json({
    required this.fontFamily,
    required this.fontSize,
    required this.color,
  });

  factory TextNodeStyle.fromJson(Object? json) {
    final style = _decode(json, 'style', _$TextNodeStyleFromJson);
    if (!textNodeFontFamilies.contains(style.fontFamily)) {
      throw const FormatException('style.fontFamily is not supported');
    }
    _validatePositive(style.fontSize, 'style.fontSize');
    if (!_canonicalColor.hasMatch(style.color)) {
      throw const FormatException('style.color must be uppercase #RRGGBB');
    }
    return style;
  }

  // ---------- State ----------

  final String fontFamily;
  final double fontSize;
  final String color;

  // ---------- Copying ----------

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

  // ---------- Serialization ----------

  Map<String, Object?> toJson() => _$TextNodeStyleToJson(this);
}

/// Stores editable text content, layout, rotation, and styling.
/// Used by text blocks and document serialization.
@_strictJson
class TextElementData extends CanvasElementData {
  // ---------- Construction ----------

  TextElementData({
    required String id,
    required this.position,
    required double width,
    required double? height,
    required this.markdown,
    required this.style,
    this.rotation = 0,
  }) : textSize = (width: width, height: height),
       super(id, 'text');

  TextElementData._json({
    required String id,
    required String type,
    required this.position,
    required this.textSize,
    required this.markdown,
    required this.style,
    required this.rotation,
  }) : super(id, type);

  factory TextElementData.fromJson(Object? json) {
    final text = _decode(json, 'text element', _$TextElementDataFromJson)..validateType('text');
    if (text.width < textNodeMinimumWidth) {
      throw const FormatException('element.size.width is below the minimum');
    }
    if (text.height != null && text.height! < textNodeMinimumHeight) {
      throw const FormatException('element.size.height is below the minimum');
    }
    _validateFinite(text.rotation, 'element.rotation');
    return text;
  }

  // ---------- State ----------

  @_OffsetConverter()
  Offset position;
  @JsonKey(name: 'size', fromJson: _textSizeFromJson, toJson: _textSizeToJson)
  ({double width, double? height}) textSize;
  String markdown;
  TextNodeStyle style;
  double rotation;

  @JsonKey(includeFromJson: false, includeToJson: false)
  double get width => textSize.width;
  set width(double value) => textSize = (width: value, height: height);

  @JsonKey(includeFromJson: false, includeToJson: false)
  double? get height => textSize.height;
  set height(double? value) => textSize = (width: width, height: value);

  // ---------- Serialization ----------

  @override
  Map<String, Object?> toJson() => _$TextElementDataToJson(this);

  // ---------- Copying ----------

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

/// Stores source code, language, position, and size for a code block.
/// Used by code block models and document serialization.
@_strictJson
class CodeElementData extends CanvasElementData {
  // ---------- Construction ----------

  CodeElementData({
    required String id,
    required this.position,
    required this.size,
    required this.language,
    required this.source,
  }) : super(id, 'code');

  CodeElementData._json({
    required String id,
    required String type,
    required this.position,
    required this.size,
    required this.language,
    required this.source,
  }) : super(id, type);

  factory CodeElementData.fromJson(Object? json) {
    final code = _decode(json, 'code element', _$CodeElementDataFromJson)..validateType('code');
    if (code.size.width < codeBlockMinimumSize.width || code.size.height < codeBlockMinimumSize.height) {
      throw const FormatException('element.size is below the minimum');
    }
    return code;
  }

  // ---------- State ----------

  @_OffsetConverter()
  Offset position;
  @_SizeConverter()
  Size size;
  CodeLanguage language;
  String source;

  // ---------- Serialization ----------

  @override
  Map<String, Object?> toJson() => _$CodeElementDataToJson(this);

  // ---------- Copying ----------

  @override
  CodeElementData copy({String? id}) => CodeElementData(
    id: id ?? this.id,
    position: position,
    size: size,
    language: language,
    source: source,
  );
}

/// Stores a sampled pen position and its input pressure.
/// Used by pen strokes during rendering and serialization.
@_strictJson
final class PenPointData {
  // ---------- Construction ----------

  const PenPointData(this.position, {required this.pressure});

  PenPointData._json({
    required double x,
    required double y,
    required this.pressure,
  }) : position = Offset(x, y);

  factory PenPointData.fromJson(Object? json) {
    final point = _decode(json, 'pen point', _$PenPointDataFromJson);
    _validateFinite(point.x, 'point.x');
    _validateFinite(point.y, 'point.y');
    _validateFinite(point.pressure, 'point.pressure');
    if (point.pressure < 0 || point.pressure > 1) {
      throw const FormatException('point.pressure must be between 0 and 1');
    }
    return point;
  }

  // ---------- State ----------

  @JsonKey(includeFromJson: false, includeToJson: false)
  final Offset position;
  final double pressure;

  double get x => position.dx;
  double get y => position.dy;

  // ---------- Serialization ----------

  Map<String, Object?> toJson() => _$PenPointDataToJson(this);
}

/// Stores the sampled path and appearance of a freehand pen stroke.
/// Used by pen stroke models and document serialization.
@_strictJson
class PenElementData extends CanvasElementData {
  // ---------- Construction ----------

  PenElementData({
    required String id,
    required this.position,
    required this.size,
    required this.hitSlop,
    required this.points,
    required this.color,
    required this.width,
  }) : super(id, 'pen');

  PenElementData._json({
    required String id,
    required String type,
    required this.position,
    required this.size,
    required this.hitSlop,
    required this.points,
    required this.color,
    required this.width,
  }) : super(id, type);

  factory PenElementData.fromJson(Object? json) {
    final pen = _decode(json, 'pen element', _$PenElementDataFromJson)..validateType('pen');
    _validateFinite(pen.hitSlop, 'element.hitSlop');
    if (pen.hitSlop < 0) {
      throw const FormatException('element.hitSlop must be non-negative');
    }
    if (pen.points.isEmpty) {
      throw const FormatException('element.points must not be empty');
    }
    _validateArgb(pen.color, 'element.color');
    _validatePositive(pen.width, 'element.width');
    return pen;
  }

  // ---------- State ----------

  @_OffsetConverter()
  Offset position;
  @_SizeConverter()
  Size size;
  double hitSlop;
  List<PenPointData> points;
  @JsonKey(fromJson: _jsonInt)
  int color;
  double width;

  // ---------- Serialization ----------

  @override
  Map<String, Object?> toJson() => _$PenElementDataToJson(this);

  // ---------- Copying ----------

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

/// Stores the control points that define a curved arrow.
/// Used by arrow models and document serialization.
@_strictJson
class ArrowElementData extends CanvasElementData {
  // ---------- Construction ----------

  ArrowElementData({
    required String id,
    required this.start,
    required this.control,
    required this.end,
  }) : super(id, 'arrow');

  ArrowElementData._json({
    required String id,
    required String type,
    required this.start,
    required this.control,
    required this.end,
  }) : super(id, type);

  factory ArrowElementData.fromJson(Object? json) {
    final arrow = _decode(json, 'arrow element', _$ArrowElementDataFromJson)..validateType('arrow');
    if ((arrow.end - arrow.start).distance < arrowMinimumLength) {
      throw const FormatException('element arrow is shorter than the minimum');
    }
    return arrow;
  }

  // ---------- State ----------

  @_OffsetConverter()
  Offset start;
  @_OffsetConverter()
  Offset control;
  @_OffsetConverter()
  Offset end;

  // ---------- Serialization ----------

  @override
  Map<String, Object?> toJson() => _$ArrowElementDataToJson(this);

  // ---------- Copying ----------

  @override
  ArrowElementData copy({String? id}) => ArrowElementData(
    id: id ?? this.id,
    start: start,
    control: control,
    end: end,
  );
}

// ---------- Domain validation ----------

final _canonicalColor = RegExp(r'^#[0-9A-F]{6}$');

void _validateFinite(double value, String field) {
  if (!value.isFinite) throw FormatException('$field must be finite');
}

void _validatePositive(double value, String field) {
  _validateFinite(value, field);
  if (value <= 0) throw FormatException('$field must be positive');
}

void _validateArgb(int value, String field) {
  if (value < 0 || value > 0xffffffff) {
    throw FormatException('$field must be an ARGB integer');
  }
}
