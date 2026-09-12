// Provides the app's compact floating HSV color picker.
// Used by editor popovers that need direct color selection.

import 'package:beyond/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------- Geometry ----------

const _popoverWidth = 232.0;
const _panelRadius = BorderRadius.all(Radius.circular(14));
const _pickerRadius = BorderRadius.all(Radius.circular(8));
const _trackRadius = BorderRadius.all(Radius.circular(5));
const _trackHeight = 10.0;
const _handleRadius = 7.0;
const _fieldHeight = 30.0;

// ---------- Color picker ----------

/// Renders a compact saturation, hue, alpha, and hex color editor.
class ColorPickerWidget extends StatefulWidget {
  const ColorPickerWidget({
    required this.color,
    required this.onChanged,
    super.key,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<ColorPickerWidget> createState() => _ColorPickerWidgetState();
}

class _ColorPickerWidgetState extends State<ColorPickerWidget> {
  // ---------- State ----------

  late HSVColor _hsv;
  late double _alpha;
  late final TextEditingController _hexController;
  final _hexFocusNode = FocusNode();

  // ---------- Lifecycle ----------

  @override
  void initState() {
    super.initState();
    _syncFrom(widget.color);
    _hexController = TextEditingController(text: _hex(widget.color));
    _hexFocusNode.addListener(_handleHexFocus);
  }

  @override
  void didUpdateWidget(covariant ColorPickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color.toARGB32() == widget.color.toARGB32()) return;
    _syncFrom(widget.color);
    if (!_hexFocusNode.hasFocus) _setHexText(_hex(widget.color));
  }

  @override
  void dispose() {
    _hexFocusNode
      ..removeListener(_handleHexFocus)
      ..dispose();
    _hexController.dispose();
    super.dispose();
  }

  // ---------- Rendering ----------

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;

    return SizedBox(
      width: _popoverWidth,
      child: Material(
        color: colors.surfaceRaised,
        elevation: theme.geo.elevationLow,
        shadowColor: colors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: _panelRadius,
          side: BorderSide(color: colors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _SaturationValuePicker(
                  hsv: _hsv,
                  colors: colors,
                  onChanged: _setSaturationValue,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 16,
                child: _HuePicker(
                  hue: _hsv.hue,
                  colors: colors,
                  onChanged: _setHue,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 16,
                child: _AlphaPicker(
                  alpha: _alpha,
                  color: _hsv.withAlpha(1).toColor(),
                  colors: colors,
                  onChanged: _setAlpha,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox.square(
                    dimension: 24,
                    child: CustomPaint(
                      painter: _PreviewPainter(_color, colors.surfacePressed),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: _fieldHeight,
                      child: TextField(
                        controller: _hexController,
                        focusNode: _hexFocusNode,
                        maxLength: 9,
                        autocorrect: false,
                        enableSuggestions: false,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]'))],
                        style: theme.typo.body.copyWith(fontSize: 11),
                        decoration: _inputDecoration(theme),
                        onChanged: _setHex,
                        onSubmitted: (_) => _normalizeHex(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BTheme theme) {
    final colors = theme.colors;
    return InputDecoration(
      counterText: '',
      isDense: true,
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      enabledBorder: OutlineInputBorder(
        borderRadius: theme.geo.radiusMedium,
        borderSide: BorderSide(color: colors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: theme.geo.radiusMedium,
        borderSide: BorderSide(color: colors.focusRing, width: 2),
      ),
    );
  }

  // ---------- Changes ----------

  Color get _color => _hsv.withAlpha(_alpha).toColor();

  void _setSaturationValue(double saturation, double value) {
    _change(_hsv.withSaturation(saturation).withValue(value));
  }

  void _setHue(double hue) => _change(_hsv.withHue(hue));

  void _setAlpha(double alpha) {
    setState(() => _alpha = alpha);
    _setHexText(_hex(_color));
    widget.onChanged(_color);
  }

  void _setHex(String value) {
    final digits = value.startsWith('#') ? value.substring(1) : value;
    if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(digits)) return;
    final color = Color(int.parse('ff${digits.substring(0, 6)}', radix: 16));
    final alpha = digits.length == 8 ? int.parse(digits.substring(6), radix: 16) / 255 : 1.0;
    setState(() {
      _alpha = alpha;
      _hsv = HSVColor.fromColor(color).withAlpha(alpha);
    });
    widget.onChanged(_color);
  }

  void _change(HSVColor hsv) {
    setState(() => _hsv = hsv.withAlpha(_alpha));
    _setHexText(_hex(_color));
    widget.onChanged(_color);
  }

  // ---------- Helpers ----------

  void _syncFrom(Color color) {
    _alpha = color.a;
    _hsv = HSVColor.fromColor(color);
  }

  void _handleHexFocus() {
    if (!_hexFocusNode.hasFocus) _normalizeHex();
  }

  void _normalizeHex() => _setHexText(_hex(_color));

  void _setHexText(String value) {
    _hexController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  static String _hex(Color color) {
    final argb = color.toARGB32();
    final rgb = (argb & 0x00ffffff).toRadixString(16).padLeft(6, '0');
    final alpha = argb >>> 24;
    final alphaSuffix = alpha == 255 ? '' : alpha.toRadixString(16).padLeft(2, '0');
    return '#${(rgb + alphaSuffix).toUpperCase()}';
  }
}

// ---------- Picker surfaces ----------

class _SaturationValuePicker extends StatelessWidget {
  const _SaturationValuePicker({
    required this.hsv,
    required this.colors,
    required this.onChanged,
  });

  final HSVColor hsv;
  final BColors colors;
  final void Function(double saturation, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(Offset position) {
          onChanged(
            (position.dx / constraints.maxWidth).clamp(0, 1),
            1 - (position.dy / constraints.maxHeight).clamp(0, 1),
          );
        }

        return Semantics(
          label: 'Saturation and brightness',
          value: '${(hsv.saturation * 100).round()}% saturation, ${(hsv.value * 100).round()}% brightness',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => update(details.localPosition),
              onPanStart: (details) => update(details.localPosition),
              onPanUpdate: (details) => update(details.localPosition),
              child: CustomPaint(
                painter: _SaturationValuePainter(hsv, colors.surfaceRaised, colors.textPrimary),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HuePicker extends StatelessWidget {
  const _HuePicker({required this.hue, required this.colors, required this.onChanged});

  final double hue;
  final BColors colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(Offset position) => onChanged((position.dx / constraints.maxWidth).clamp(0, 1) * 360);

        return Semantics(
          slider: true,
          label: 'Hue',
          value: '${hue.round()} degrees',
          onIncrease: () => onChanged((hue + 5).clamp(0, 360)),
          onDecrease: () => onChanged((hue - 5).clamp(0, 360)),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => update(details.localPosition),
              onPanStart: (details) => update(details.localPosition),
              onPanUpdate: (details) => update(details.localPosition),
              child: CustomPaint(
                painter: _HuePainter(hue, colors.surfaceRaised, colors.textPrimary),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AlphaPicker extends StatelessWidget {
  const _AlphaPicker({
    required this.alpha,
    required this.color,
    required this.colors,
    required this.onChanged,
  });

  final double alpha;
  final Color color;
  final BColors colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void update(Offset position) => onChanged((position.dx / constraints.maxWidth).clamp(0, 1));

        return Semantics(
          slider: true,
          label: 'Alpha',
          value: '${(alpha * 100).round()}%',
          onIncrease: () => onChanged((alpha + 0.05).clamp(0, 1)),
          onDecrease: () => onChanged((alpha - 0.05).clamp(0, 1)),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => update(details.localPosition),
              onPanStart: (details) => update(details.localPosition),
              onPanUpdate: (details) => update(details.localPosition),
              child: CustomPaint(
                painter: _AlphaPainter(alpha, color, colors.surfacePressed, colors.surfaceRaised, colors.textPrimary),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------- Painting ----------

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter(this.hsv, this.handle, this.handleBorder);

  final HSVColor hsv;
  final Color handle;
  final Color handleBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas
      ..save()
      ..clipRRect(_pickerRadius.toRRect(rect))
      ..drawRect(rect, Paint()..color = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor())
      ..drawRect(
        rect,
        Paint()..shader = const LinearGradient(colors: [Colors.white, Colors.transparent]).createShader(rect),
      )
      ..drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
          ).createShader(rect),
      )
      ..restore();

    _paintHandle(
      canvas,
      Offset(
        (hsv.saturation * size.width).clamp(_handleRadius, size.width - _handleRadius),
        ((1 - hsv.value) * size.height).clamp(_handleRadius, size.height - _handleRadius),
      ),
      handle,
      handleBorder,
    );
  }

  @override
  bool shouldRepaint(_SaturationValuePainter oldDelegate) =>
      oldDelegate.hsv != hsv || oldDelegate.handle != handle || oldDelegate.handleBorder != handleBorder;
}

class _HuePainter extends CustomPainter {
  const _HuePainter(this.hue, this.handle, this.handleBorder);

  static const _colors = [
    Color(0xffff0000),
    Color(0xffffff00),
    Color(0xff00ff00),
    Color(0xff00ffff),
    Color(0xff0000ff),
    Color(0xffff00ff),
    Color(0xffff0000),
  ];

  final double hue;
  final Color handle;
  final Color handleBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Rect.fromLTWH(0, (size.height - _trackHeight) / 2, size.width, _trackHeight);
    canvas
      ..save()
      ..clipRRect(_trackRadius.toRRect(track))
      ..drawRect(track, Paint()..shader = const LinearGradient(colors: _colors).createShader(track))
      ..restore();
    _paintHandle(
      canvas,
      Offset(
        (hue / 360 * size.width).clamp(_handleRadius, size.width - _handleRadius),
        size.height / 2,
      ),
      handle,
      handleBorder,
    );
  }

  @override
  bool shouldRepaint(_HuePainter oldDelegate) =>
      oldDelegate.hue != hue || oldDelegate.handle != handle || oldDelegate.handleBorder != handleBorder;
}

class _AlphaPainter extends CustomPainter {
  const _AlphaPainter(this.alpha, this.color, this.checker, this.handle, this.handleBorder);

  final double alpha;
  final Color color;
  final Color checker;
  final Color handle;
  final Color handleBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Rect.fromLTWH(0, (size.height - _trackHeight) / 2, size.width, _trackHeight);
    canvas
      ..save()
      ..clipRRect(_trackRadius.toRRect(track))
      ..drawRect(track, Paint()..color = Colors.white);
    _paintCheckerboard(canvas, track, checker, 5);
    canvas
      ..drawRect(
        track,
        Paint()..shader = LinearGradient(colors: [color.withValues(alpha: 0), color]).createShader(track),
      )
      ..restore();
    _paintHandle(
      canvas,
      Offset(
        (alpha * size.width).clamp(_handleRadius, size.width - _handleRadius),
        size.height / 2,
      ),
      handle,
      handleBorder,
    );
  }

  @override
  bool shouldRepaint(_AlphaPainter oldDelegate) =>
      oldDelegate.alpha != alpha ||
      oldDelegate.color != color ||
      oldDelegate.checker != checker ||
      oldDelegate.handle != handle ||
      oldDelegate.handleBorder != handleBorder;
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(this.color, this.checker);

  final Color color;
  final Color checker;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rounded = _pickerRadius.toRRect(rect);
    canvas
      ..save()
      ..clipRRect(rounded, doAntiAlias: false)
      ..drawRect(rect, Paint()..color = Colors.white);
    _paintCheckerboard(canvas, rect, checker, 6);
    canvas
      ..drawRect(rect, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) => oldDelegate.color != color || oldDelegate.checker != checker;
}

void _paintCheckerboard(Canvas canvas, Rect rect, Color checker, double square) {
  for (var y = rect.top; y < rect.bottom; y += square) {
    for (var x = rect.left; x < rect.right; x += square) {
      if (((x - rect.left) ~/ square + (y - rect.top) ~/ square).isEven) {
        canvas.drawRect(Rect.fromLTWH(x, y, square, square), Paint()..color = checker);
      }
    }
  }
}

void _paintHandle(Canvas canvas, Offset center, Color fill, Color border) {
  canvas
    ..drawCircle(center.translate(0, 1), _handleRadius, Paint()..color = Colors.black.withValues(alpha: 0.16))
    ..drawCircle(center, _handleRadius, Paint()..color = fill)
    ..drawCircle(
      center,
      _handleRadius - 0.5,
      Paint()
        ..color = border.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke,
    );
}
