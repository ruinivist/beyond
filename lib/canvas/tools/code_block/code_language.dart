import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

enum CodeLanguage {
  dart('Dart'),
  javascript('JavaScript'),
  typescript('TypeScript'),
  python('Python'),
  go('Go'),
  rust('Rust'),
  plainText('Plain text');

  const CodeLanguage(this.label);

  final String label;

  Mode? get mode => switch (this) {
    dart => langDart,
    javascript => langJavascript,
    typescript => langTypescript,
    python => langPython,
    go => langGo,
    rust => langRust,
    plainText => null,
  };

  CodeHighlightTheme? get theme => mode == null
      ? null
      : CodeHighlightTheme(
          languages: {name: CodeHighlightThemeMode(mode: mode!)},
          theme: atomOneDarkTheme,
        );
}
