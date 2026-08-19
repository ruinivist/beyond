import 'package:beyond/foundation/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BTheme.of fails without a registered extension', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(
      () => BTheme.of(tester.element(find.byType(SizedBox))),
      throwsFlutterError,
    );
  });
}
