import 'package:flutter/painting.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';

enum CodeLanguage {
  python('Python'),
  typescript('TypeScript'),
  javascript('JavaScript'),
  java('Java'),
  csharp('C#'),
  cpp('C++'),
  c('C'),
  go('Go'),
  rust('Rust'),
  sql('SQL'),
  bash('Bash'),
  kotlin('Kotlin'),
  swift('Swift'),
  php('PHP'),
  ruby('Ruby'),
  dart('Dart'),
  html('HTML'),
  css('CSS'),
  json('JSON'),
  yaml('YAML'),
  markdown('Markdown'),
  plainText('Plain text');

  const CodeLanguage(this.label);

  final String label;

  Mode? get mode => switch (this) {
    python => langPython,
    typescript => langTypescript,
    javascript => langJavascript,
    java => langJava,
    csharp => langCsharp,
    cpp => langCpp,
    c => langC,
    go => langGo,
    rust => langRust,
    sql => langSql,
    bash => langBash,
    kotlin => langKotlin,
    swift => langSwift,
    php => langPhp,
    ruby => langRuby,
    dart => langDart,
    html => langXml,
    css => langCss,
    json => langJson,
    yaml => langYaml,
    markdown => langMarkdown,
    plainText => null,
  };

  CodeHighlightTheme? theme(Map<String, TextStyle> styles) => mode == null
      ? null
      : CodeHighlightTheme(
          languages: {name: CodeHighlightThemeMode(mode: mode!)},
          theme: styles,
        );
}
