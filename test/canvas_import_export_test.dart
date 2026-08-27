import 'dart:async';
import 'dart:convert';

import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/canvas_project.dart';
import 'package:beyond/canvas/canvas_project_files.dart';
import 'package:beyond/canvas/tools/arrow/arrow_tool.dart';
import 'package:beyond/canvas/tools/code_block/code_block.dart';
import 'package:beyond/canvas/tools/code_block/code_language.dart';
import 'package:beyond/canvas/tools/pen/pen_tool.dart';
import 'package:beyond/canvas/tools/text/text_block.dart';
import 'package:beyond/foundation/select.dart';
import 'package:beyond/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_lazy_grid/infinite_lazy_grid.dart';
import 'package:scribble/scribble.dart';

void main() {
  testWidgets('exports the current durable project', (tester) async {
    final document = _document(markdown: '![image]($_path0)');
    final documentStore = _FakeDocumentStore(document);
    final attachments = _FakeAttachmentStore({_path0: _oldBytes});
    final files = _FakeProjectFiles();

    await _pumpPage(tester, documentStore, attachments, files);
    await _openCanvasSettings(tester);
    await tester.tap(find.byKey(const ValueKey('canvas-export-button')));
    await tester.pumpAndSettle();

    expect(files.saved, isNotNull);
    final root = jsonDecode(utf8.decode(files.saved!)) as Map<String, dynamic>;
    expect(root['format'], 'beyond-canvas');
    expect(root['document'], document.toJson());
    expect(root['attachments'], {_path0: base64Encode(_oldBytes)});
    expect(find.text('Canvas exported'), findsOneWidget);
  });

  testWidgets('canceled file operations are silent', (tester) async {
    final files = _FakeProjectFiles()..cancelOpen = true;
    await _pumpPage(
      tester,
      _FakeDocumentStore(_document(markdown: '')),
      _FakeAttachmentStore(),
      files,
    );
    await _openCanvasSettings(tester);
    await tester.tap(find.byKey(const ValueKey('canvas-import-button')));
    await tester.pumpAndSettle();
    expect(files.openCalls, 1);
    expect(find.text('Canvas imported'), findsNothing);
    expect(find.text('Could not import canvas'), findsNothing);

    files
      ..cancelOpen = false
      ..cancelSave = true;
    await tester.tap(find.byKey(const ValueKey('canvas-export-button')));
    await tester.pumpAndSettle();
    expect(find.text('Canvas exported'), findsNothing);
    expect(find.text('Could not export canvas'), findsNothing);
  });

  testWidgets('valid import replaces, persists, and preserves the viewport', (
    tester,
  ) async {
    final oldDocument = _document(markdown: 'old');
    final newDocument = _document(
      markdown: '![new]($_path0)',
      background: CanvasBackgroundKind.dotGrid,
      idSuffix: '-new',
    );
    final attachments = _FakeAttachmentStore({_path0: _oldBytes});
    final documentStore = _FakeDocumentStore(oldDocument);
    final files = _FakeProjectFiles()
      ..opened = await encodeCanvasProject(
        newDocument,
        _FakeAttachmentStore({_path0: _newBytes}),
      );

    await _pumpPage(tester, documentStore, attachments, files);
    tester.widget<TextBlock>(find.byType(TextBlock)).model.selected = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    await _historyShortcut(tester);
    expect(find.byType(TextBlock), findsOneWidget);

    final controller = _canvasController(tester)
      ..scrollBy(const Offset(90, 60))
      ..updateScalebyDelta(0.25);
    await tester.pump();
    final offset = controller.offset;
    final scale = controller.scale;

    await _openCanvasSettings(tester);
    await tester.tap(find.byKey(const ValueKey('canvas-import-button')));
    await tester.pumpAndSettle();

    expect(find.text('Canvas imported'), findsOneWidget);
    expect(documentStore.persisted?.toJson(), newDocument.toJson());
    expect(attachments.files[_path0], _newBytes);
    expect(_canvasController(tester).offset, offset);
    expect(_canvasController(tester).scale, scale);
    expect(find.byType(TextBlock), findsOneWidget);
    expect(find.byType(CodeBlock), findsOneWidget);
    expect(find.byType(PenStroke), findsOneWidget);
    expect(find.byType(Arrow), findsOneWidget);
    expect(
      tester.widget<TextBlock>(find.byType(TextBlock)).model.selected,
      isFalse,
    );
    expect(
      tester.widget<TextBlock>(find.byType(TextBlock)).model.focusNode.hasFocus,
      isFalse,
    );

    await _historyShortcut(tester, redo: true);
    expect(
      tester.widget<TextBlock>(find.byType(TextBlock)).model.node.markdown,
      '![new]($_path0)',
    );

    documentStore.initial = documentStore.persisted;
    await tester.pumpWidget(
      BeyondApp(
        documentStore: documentStore,
        attachmentStore: attachments,
        projectFiles: files,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextBlock), findsOneWidget);
    expect(
      tester.widget<TextBlock>(find.byType(TextBlock)).model.node.markdown,
      '![new]($_path0)',
    );
  });

  testWidgets(
    'import blocks keyboard and background mutations while committing',
    (
      tester,
    ) async {
      final oldDocument = _document(
        markdown: '![old]($_path0)',
      );
      final newDocument = _document(
        markdown: '![new]($_path0)',
        background: CanvasBackgroundKind.dotGrid,
        idSuffix: '-new',
      );
      final attachments = _FakeAttachmentStore({_path0: _oldBytes});
      final documentStore = _FakeDocumentStore(oldDocument);
      final files = _FakeProjectFiles()
        ..opened = await encodeCanvasProject(
          newDocument,
          _FakeAttachmentStore({_path0: _newBytes}),
        );

      await _pumpPage(tester, documentStore, attachments, files);
      await _openCanvasSettings(tester);
      tester.widget<TextBlock>(find.byType(TextBlock)).model.selected = true;
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump();

      final writeGate = Completer<void>();
      attachments.writeGate = writeGate;
      await tester.tap(find.byKey(const ValueKey('canvas-import-button')));
      for (var index = 0; index < 10 && !attachments.writeStarted; index++) {
        await tester.pump();
      }
      expect(attachments.writeStarted, isTrue);

      tester
          .widget<Select<CanvasBackgroundKind>>(
            find.byKey(const ValueKey('canvas-background-select')),
          )
          .onChanged!
          .call(CanvasBackgroundKind.dotGrid);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      attachments.failNextWrite = true;
      writeGate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(TextBlock), findsOneWidget);
      expect(
        tester.widget<TextBlock>(find.byType(TextBlock)).model.node.markdown,
        oldDocument.elements.whereType<TextElementData>().single.markdown,
      );
      expect(
        tester.widget<TextBlock>(find.byType(TextBlock)).model.selected,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('canvas-export-button')));
      await tester.pumpAndSettle();
      final root =
          jsonDecode(utf8.decode(files.saved!)) as Map<String, dynamic>;
      final exportedDocument = root['document'] as Map<String, dynamic>;
      expect(exportedDocument['background'], CanvasBackgroundKind.plain.name);
    },
  );

  testWidgets(
    'failed dirty flush aborts import and preserves edits for restart',
    (
      tester,
    ) async {
      final oldDocument = _document(markdown: 'old');
      final newDocument = _document(markdown: 'imported', idSuffix: '-new');
      final attachments = _FakeAttachmentStore();
      final documentStore = _FakeDocumentStore(oldDocument)..failSaves = true;
      final files = _FakeProjectFiles()
        ..opened = await encodeCanvasProject(
          newDocument,
          _FakeAttachmentStore(),
        );

      await _pumpPage(tester, documentStore, attachments, files);
      await _openCanvasSettings(tester);
      tester
          .widget<TextBlock>(find.byType(TextBlock))
          .model
          .insertPastedText(' dirty');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('canvas-import-button')));
      await tester.pumpAndSettle();

      expect(find.text('Could not import canvas'), findsOneWidget);
      expect(files.writeCalls, 0);
      expect(documentStore.saveCalls, 1);
      expect(documentStore.persisted, isNull);
      expect(
        tester.widget<TextBlock>(find.byType(TextBlock)).model.node.markdown,
        'old dirty',
      );

      documentStore.failSaves = false;
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(documentStore.persisted, isNotNull);

      documentStore.initial = documentStore.persisted;
      await tester.pumpWidget(
        BeyondApp(
          documentStore: documentStore,
          attachmentStore: attachments,
          projectFiles: files,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<TextBlock>(find.byType(TextBlock)).model.node.markdown,
        'old dirty',
      );
    },
  );

  testWidgets('failed attachment and document commits roll back safely', (
    tester,
  ) async {
    final oldDocument = _document(markdown: '![old]($_path0)');
    final newDocument = _document(
      markdown: '![new]($_path0)',
      idSuffix: '-new',
    );
    final attachments = _FakeAttachmentStore({_path0: _oldBytes});
    final documentStore = _FakeDocumentStore(oldDocument)..failSaves = true;
    final files = _FakeProjectFiles()
      ..opened = await encodeCanvasProject(
        newDocument,
        _FakeAttachmentStore({_path0: _newBytes}),
      );

    await _pumpPage(tester, documentStore, attachments, files);
    await _openCanvasSettings(tester);
    await tester.tap(find.byKey(const ValueKey('canvas-import-button')));
    await tester.pumpAndSettle();

    expect(find.text('Could not import canvas'), findsOneWidget);
    expect(attachments.files[_path0], _oldBytes);
    expect(documentStore.persisted, isNull);
    expect(
      tester.widget<TextBlock>(find.byType(TextBlock)).model.node.markdown,
      oldDocument.elements.whereType<TextElementData>().single.markdown,
    );

    attachments.failNextWrite = true;
    await tester.tap(find.byKey(const ValueKey('canvas-import-button')));
    await tester.pumpAndSettle();
    expect(find.text('Could not import canvas'), findsOneWidget);
    expect(attachments.files[_path0], _oldBytes);
    expect(documentStore.persisted, isNull);

    documentStore.failSaves = false;
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    tester
        .widget<TextBlock>(find.byType(TextBlock))
        .model
        .insertPastedText(' changed');
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    expect(documentStore.saveCalls, greaterThan(1));
  });

  testWidgets('malformed import and repeated transfer are ignored safely', (
    tester,
  ) async {
    final files = _FakeProjectFiles()
      ..opened = Uint8List.fromList(utf8.encode('{"format":"wrong"}'));
    await _pumpPage(
      tester,
      _FakeDocumentStore(_document(markdown: 'unchanged')),
      _FakeAttachmentStore(),
      files,
    );
    await _openCanvasSettings(tester);
    await tester.tap(find.byKey(const ValueKey('canvas-import-button')));
    await tester.pumpAndSettle();
    expect(find.text('Could not import canvas'), findsOneWidget);
    expect(files.writeCalls, 0);

    final completer = Completer<Uint8List?>();
    files
      ..opened = null
      ..openCompleter = completer;
    await tester.tap(find.byKey(const ValueKey('canvas-import-button')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('canvas-import-button')));
    expect(files.openCalls, 2);
    completer.complete(null);
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeDocumentStore documentStore,
  _FakeAttachmentStore attachments,
  _FakeProjectFiles files,
) async {
  await tester.pumpWidget(
    BeyondApp(
      documentStore: documentStore,
      attachmentStore: attachments,
      projectFiles: files,
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _openCanvasSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('settings-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Canvas').last);
  await tester.pumpAndSettle();
}

Future<void> _historyShortcut(WidgetTester tester, {bool redo = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (redo) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
  if (redo) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

LazyCanvasController _canvasController(WidgetTester tester) =>
    tester.widget<LazyCanvas>(find.byType(LazyCanvas)).controller;

CanvasDocument _document({
  required String markdown,
  CanvasBackgroundKind background = CanvasBackgroundKind.plain,
  String idSuffix = '',
}) => CanvasDocument(
  background: background,
  elements: [
    TextElementData(
      id: 'text$idSuffix',
      position: const Offset(10, 20),
      width: 280,
      height: null,
      markdown: markdown,
      style: const TextNodeStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        color: '#201C1A',
      ),
    ),
    CodeElementData(
      id: 'code$idSuffix',
      position: const Offset(40, 50),
      size: const Size(280, 240),
      language: CodeLanguage.dart,
      source: 'void main() {}',
    ),
    PenElementData(
      id: 'pen$idSuffix',
      position: Offset.zero,
      size: const Size(10, 10),
      hitSlop: 0,
      sketch: const Sketch(
        lines: [
          SketchLine(
            color: 0xff000000,
            width: 1,
            points: [Point(0, 0, pressure: 0)],
          ),
        ],
      ),
    ),
    ArrowElementData(
      id: 'arrow$idSuffix',
      start: Offset.zero,
      control: const Offset(10, 4),
      end: const Offset(20, 0),
    ),
  ],
);

const _path0 = 'attachments/00000000-0000-4000-8000-000000000000.png';
final _oldBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=',
  ),
);
final _newBytes = Uint8List.fromList(
  base64Decode('R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=='),
);

class _FakeDocumentStore extends CanvasDocumentStore {
  _FakeDocumentStore(this.initial);

  CanvasDocument? initial;
  CanvasDocument? persisted;
  bool failSaves = false;
  int saveCalls = 0;

  @override
  Future<CanvasDocument?> load() async => initial?.copy();

  @override
  Future<void> save(CanvasDocument document) async {
    saveCalls++;
    if (failSaves) throw StateError('save failed');
    persisted = document.copy();
  }
}

class _FakeAttachmentStore implements AttachmentStore {
  _FakeAttachmentStore([Map<String, Uint8List>? initial])
    : files = {...?initial};

  final Map<String, Uint8List> files;
  int writeCalls = 0;
  bool failNextWrite = false;
  Completer<void>? writeGate;
  bool writeStarted = false;

  @override
  Future<void> write(String path, Uint8List bytes) async {
    writeCalls++;
    writeStarted = true;
    final gate = writeGate;
    if (gate != null) {
      writeGate = null;
      await gate.future;
    }
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('write failed');
    }
    files[path] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> read(String path) async {
    final bytes = files[path];
    if (bytes == null) throw StateError('missing attachment');
    return bytes;
  }

  @override
  Future<Uint8List?> readIfExists(String path) async => files[path];
}

class _FakeProjectFiles implements CanvasProjectFiles {
  Uint8List? opened;
  Uint8List? saved;
  Completer<Uint8List?>? openCompleter;
  bool cancelOpen = false;
  bool cancelSave = false;
  int openCalls = 0;
  int writeCalls = 0;

  @override
  Future<Uint8List?> open() async {
    openCalls++;
    final completer = openCompleter;
    if (completer != null) return completer.future;
    if (cancelOpen) return null;
    return opened;
  }

  @override
  Future<bool> save(Uint8List bytes) async {
    if (cancelSave) return false;
    writeCalls++;
    saved = bytes;
    return true;
  }
}
