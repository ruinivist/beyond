import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plane/foundation/button.dart';

const _colors = ButtonColors(
  primary: Colors.blue,
  onPrimary: Colors.white,
  primaryHover: Colors.lightBlue,
  primaryPressed: Colors.indigo,
  secondary: Colors.grey,
  onSecondary: Colors.black,
  surface: Colors.white,
  foreground: Colors.black,
  border: Colors.black,
  hover: Colors.white70,
  pressed: Colors.grey,
  focus: Colors.orange,
  destructive: Colors.red,
  onDestructive: Colors.white,
  destructiveHover: Colors.redAccent,
  destructivePressed: Colors.red,
  disabled: Colors.grey,
  disabledForeground: Colors.black38,
);

void main() {
  testWidgets('button variants use expanded default spacing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Button(
          colors: _colors,
          variant: ButtonVariant.outline,
          onPressed: _noop,
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          child: Text('Outline'),
        ),
      ),
    );

    final textButton = tester.widget<TextButton>(find.byType(TextButton));
    expect(textButton.style!.minimumSize!.resolve({}), const Size(0, 40));
    expect(
      textButton.style!.padding!.resolve({}),
      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
    expect(
      textButton.style!.textStyle!.resolve({})!.fontWeight,
      FontWeight.w400,
    );
    expect(textButton.style!.backgroundColor!.resolve({}), Colors.white);
    expect(
      textButton.style!.side!.resolve({}),
      const BorderSide(color: Colors.black),
    );
  });
}

void _noop() {}
