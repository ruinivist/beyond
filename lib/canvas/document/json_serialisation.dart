// Provides private strict JSON decoding and Flutter geometry converters.
// Included by the canvas document library; not a public helper API.

part of 'canvas_document.dart';

const _strictJson = JsonSerializable(
  checked: true,
  disallowUnrecognizedKeys: true,
  explicitToJson: true,
  includeIfNull: false,
  constructor: '_json',
);

T _decode<T>(
  Object? json,
  String field,
  T Function(Map<String, dynamic>) decode,
) {
  try {
    return decode(_jsonMap(json, field));
  } on CheckedFromJsonException catch (error) {
    throw FormatException(error.toString());
  }
}

Map<String, dynamic> _jsonMap(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object');
  if (value.keys.any((key) => key is! String)) {
    throw FormatException('$field must have string keys');
  }
  return value.cast<String, dynamic>();
}

int _jsonInt(Object? value) {
  if (value is! int) throw const FormatException('value must be an integer');
  return value;
}

int? _nullableJsonInt(Object? value) => value == null ? null : _jsonInt(value);

({double width, double? height}) _textSizeFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['width', 'height'],
    requiredKeys: const ['width'],
  );
  final width = (json['width'] as num).toDouble();
  final height = (json['height'] as num?)?.toDouble();
  _validateFinite(width, 'element.size.width');
  if (height != null) _validateFinite(height, 'element.size.height');
  return (width: width, height: height);
}

Map<String, Object?> _textSizeToJson(
  ({double width, double? height}) size,
) => <String, Object?>{'width': size.width, 'height': ?size.height};

final class _OffsetConverter extends JsonConverter<Offset, Map<String, dynamic>> {
  const _OffsetConverter();

  @override
  Offset fromJson(Map<String, dynamic> json) {
    $checkKeys(
      json,
      allowedKeys: const ['x', 'y'],
      requiredKeys: const ['x', 'y'],
    );
    final offset = Offset(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    );
    _validateFinite(offset.dx, 'offset.x');
    _validateFinite(offset.dy, 'offset.y');
    return offset;
  }

  @override
  Map<String, Object> toJson(Offset value) => <String, Object>{
    'x': value.dx,
    'y': value.dy,
  };
}

final class _SizeConverter extends JsonConverter<Size, Map<String, dynamic>> {
  const _SizeConverter();

  @override
  Size fromJson(Map<String, dynamic> json) {
    $checkKeys(
      json,
      allowedKeys: const ['width', 'height'],
      requiredKeys: const ['width', 'height'],
    );
    final size = Size(
      (json['width'] as num).toDouble(),
      (json['height'] as num).toDouble(),
    );
    _validatePositive(size.width, 'size.width');
    _validatePositive(size.height, 'size.height');
    return size;
  }

  @override
  Map<String, Object> toJson(Size value) => <String, Object>{
    'width': value.width,
    'height': value.height,
  };
}
