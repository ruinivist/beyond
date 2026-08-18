import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:beyond/theme/starless_light.dart';
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

  test('syntax token styles inherit the editor font', () {
    final syntaxTheme = starlessLightThemeData.extension<BTheme>()!.syntaxTheme;
    for (final language in CodeLanguage.values) {
      final theme = language.theme(syntaxTheme);
      if (theme == null) continue;

      for (final style in theme.theme.values) {
        expect(style.fontFamily, isNull);
      }
    }
  });
}
