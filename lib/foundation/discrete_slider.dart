import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';

const _minimum = 1;
const _maximum = 20;
const int _divisions = _maximum - _minimum;
const _trackHeight = 4.0;
const _thumbDiameter = 16.0;

class DiscreteSlider extends StatelessWidget {
  const DiscreteSlider({
    required this.value,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : assert(
         value >= _minimum && value <= _maximum,
         'value must be between 1 and 20',
       );

  final int value;
  final ValueChanged<int>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final labelStyle = theme.typo.label.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1,
    );

    return SizedBox(
      height: 88,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.accent,
            inactiveTrackColor: colors.surfacePressed,
            disabledActiveTrackColor: colors.accent.withValues(alpha: 0.38),
            disabledInactiveTrackColor: colors.surfaceSubtle,
            trackHeight: _trackHeight,
            trackShape: const RoundedRectSliderTrackShape(),
            thumbColor: colors.surfaceRaised,
            disabledThumbColor: colors.surfaceSubtle,
            thumbShape: _DiscreteSliderThumbShape(colors),
            overlayShape: SliderComponentShape.noOverlay,
            overlayColor: Colors.transparent,
            tickMarkShape: SliderTickMarkShape.noTickMark,
            valueIndicatorShape: _DiscreteSliderValueIndicatorShape(
              accentColor: colors.accent,
              backgroundColor: colors.surfaceRaised,
              borderColor: colors.borderSubtle,
              textColor: colors.textSecondary,
              textStyle: labelStyle,
            ),
            valueIndicatorColor: colors.surfaceRaised,
            valueIndicatorTextStyle: labelStyle,
            showValueIndicator: ShowValueIndicator.onDrag,
          ),
          child: Slider(
            key: const ValueKey('discrete-slider'),
            value: value.toDouble(),
            min: _minimum.toDouble(),
            max: _maximum.toDouble(),
            divisions: _divisions,
            label: '$value px',
            semanticFormatterCallback: (value) => '${value.round()} px',
            focusNode: focusNode,
            autofocus: autofocus,
            onChanged: onChanged == null
                ? null
                : (next) => onChanged!(
                    next.round().clamp(
                      _minimum,
                      _maximum,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DiscreteSliderThumbShape extends SliderComponentShape {
  const _DiscreteSliderThumbShape(this.colors);

  final BColors colors;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size.square(_thumbDiameter);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final thumbPath = Path()
      ..addOval(
        Rect.fromCircle(
          center: center,
          radius: _thumbDiameter / 2,
        ),
      );
    canvas.drawShadow(thumbPath, colors.shadow, 2, true);

    final thumbColor = Color.lerp(
      colors.surfaceSubtle,
      Color.lerp(
        colors.surfaceRaised,
        colors.surface,
        activationAnimation.value,
      ),
      enableAnimation.value,
    );
    canvas
      ..drawCircle(
        center,
        _thumbDiameter / 2,
        Paint()..color = thumbColor!,
      )
      ..drawCircle(
        center,
        _thumbDiameter / 2 - 0.5,
        Paint()
          ..color = colors.borderSubtle
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }
}

class _DiscreteSliderValueIndicatorShape extends SliderComponentShape {
  const _DiscreteSliderValueIndicatorShape({
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.textStyle,
  });

  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final TextStyle textStyle;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(48, 24);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final progress = activationAnimation.value.clamp(0.0, 1.0);
    final scale = 0.94 + progress * 0.06;
    final label = labelPainter.text?.toPlainText() ?? '';
    final separator = label.lastIndexOf(' ');
    final number = separator < 0 ? label : label.substring(0, separator);
    final unit = separator < 0 ? '' : label.substring(separator + 1);
    final numberPainter = _textPainter(
      number,
      accentColor,
      textDirection,
      textScaleFactor,
      progress,
    );
    final unitPainter = _textPainter(
      unit,
      textColor,
      textDirection,
      textScaleFactor,
      progress,
    );
    final textWidth = numberPainter.width + 4 + unitPainter.width;
    const horizontalPadding = 9.0;
    const pillHeight = 24.0;
    const pillGap = 12.0;
    final pillWidth = textWidth + horizontalPadding * 2;
    final bounds = sizeWithOverflow.isEmpty ? parentBox.size : sizeWithOverflow;
    final left = (center.dx - pillWidth / 2).clamp(
      0.0,
      (bounds.width - pillWidth).clamp(0.0, double.infinity),
    );
    final pillRect = Rect.fromLTWH(
      left,
      center.dy - pillHeight - pillGap,
      pillWidth,
      pillHeight,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(pillRect, const Radius.circular(7)));
    final canvas = context.canvas;
    final drawPath = canvas.drawPath;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(scale, scale)
      ..translate(-center.dx, -center.dy);
    drawPath(
      path,
      Paint()..color = backgroundColor.withValues(alpha: progress),
    );
    drawPath(
      path,
      Paint()
        ..color = borderColor.withValues(alpha: progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final textTop = pillRect.top + (pillHeight - numberPainter.height) / 2;
    numberPainter.paint(
      canvas,
      Offset(pillRect.left + horizontalPadding, textTop),
    );
    unitPainter.paint(
      canvas,
      Offset(
        pillRect.left + horizontalPadding + numberPainter.width + 4,
        textTop,
      ),
    );
    canvas.restore();
  }

  TextPainter _textPainter(
    String text,
    Color color,
    TextDirection textDirection,
    double textScaleFactor,
    double opacity,
  ) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(color: color.withValues(alpha: opacity)),
      ),
      textDirection: textDirection,
      textScaler: TextScaler.linear(textScaleFactor),
    )..layout();
  }
}
