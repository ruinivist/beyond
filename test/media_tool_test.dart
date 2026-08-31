import 'dart:ui' as ui;

import 'package:beyond/canvas/canvas_background.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_document_store.dart';
import 'package:beyond/canvas/canvas_page.dart';
import 'package:beyond/canvas/tools/media/media_node.dart';
import 'package:beyond/theme/starless_light.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

void main() {
  setUp(() => SharedPreferencesAsyncWeb.registerWith(null));

  testWidgets('media places as a selectable URL-only node', (tester) async {
    await _pumpCanvas(tester, _DocumentStore(_document()));

    await tester.tap(find.byKey(const ValueKey('toolbar-media')));
    await tester.pump();
    await tester.tapAt(const Offset(120, 180));
    await tester.pump();
    await tester.pump();

    final model = tester.widget<MediaNode>(find.byType(MediaNode)).model;
    expect(model.data.position, const Offset(120, 180));
    expect(model.data.width, mediaNodeDefaultWidth);
    expect(model.hasImage, isFalse);
    expect(find.byKey(const ValueKey('media-url-field')), findsOneWidget);
    expect(model.focusNode.hasFocus, isTrue);

    await tester.enterText(
      find.byKey(const ValueKey('media-url-field')),
      'http://example.com/image.png',
    );
    await tester.pump();
    expect(model.hasImage, isFalse);
    expect(find.byKey(const ValueKey('media-url-field')), findsOneWidget);

    const validUrl = 'https://example.com/new-image.png';
    await _cacheImage(validUrl);
    await tester.enterText(
      find.byKey(const ValueKey('media-url-field')),
      validUrl,
    );
    await tester.pump();
    expect(model.hasImage, isTrue);
    expect(model.active, isTrue);
    expect(find.byKey(const ValueKey('media-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('media-url-field')), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(MediaNode)));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(model.selected, isTrue);
  });

  testWidgets('loaded media activates, moves, and resizes to its ratio', (
    tester,
  ) async {
    const url = 'https://example.com/image.png';
    await _cacheImage(url);
    final store = _DocumentStore(
      _document(
        MediaElementData(
          id: 'media',
          position: const Offset(120, 150),
          width: 400,
          url: url,
        ),
      ),
    );
    await _pumpCanvas(tester, store);

    final node = find.byType(MediaNode);
    final model = tester.widget<MediaNode>(node).model;
    expect(model.hasImage, isTrue);
    expect(model.canvasSize, const Size(400, 200));
    expect(find.byKey(const ValueKey('media-url-field')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('media-image')));
    await tester.pump();
    expect(model.active, isTrue);
    expect(model.selected, isFalse);
    expect(find.byKey(const ValueKey('media-url-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('media-resize-handle')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('media-url-panel'))).dy -
          tester.getBottomLeft(find.byKey(const ValueKey('media-image'))).dy,
      16,
    );

    await tester.drag(
      find.byKey(const ValueKey('media-resize-handle')),
      const Offset(100, 50),
    );
    await tester.pump();
    expect(model.data.width, closeTo(500, 0.01));
    expect(model.canvasSize.height, closeTo(250, 0.01));

    final position = model.data.position;
    await tester.drag(
      find.byKey(const ValueKey('media-image')),
      const Offset(30, 20),
    );
    await tester.pump();
    expect(model.data.position, position + const Offset(30, 20));

    final clickAway = await tester.startGesture(
      const Offset(700, 500),
      kind: PointerDeviceKind.mouse,
    );
    await clickAway.up();
    await tester.pump();
    expect(model.active, isFalse);
    expect(find.byKey(const ValueKey('media-url-field')), findsNothing);

    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    final persisted = store.persisted!.elements.single as MediaElementData;
    expect(persisted.width, closeTo(500, 0.01));
    expect(persisted.position, position + const Offset(30, 20));
  });
}

Future<void> _pumpCanvas(
  WidgetTester tester,
  CanvasDocumentStore store,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: starlessLightThemeData,
      home: CanvasPage(documentStore: store),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _cacheImage(String url) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 200, 100),
    Paint()..color = Colors.black,
  );
  final image = await recorder.endRecording().toImage(200, 100);
  PaintingBinding.instance.imageCache.putIfAbsent(
    NetworkImage(url),
    () => OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image)),
    ),
  );
}

CanvasDocument _document([MediaElementData? media]) => CanvasDocument(
  background: CanvasBackgroundKind.plain,
  elements: [?media],
);

class _DocumentStore extends CanvasDocumentStore {
  _DocumentStore(this.initial);

  final CanvasDocument initial;
  CanvasDocument? persisted;

  @override
  Future<CanvasDocument?> load() async => initial.copy();

  @override
  Future<void> save(CanvasDocument document) async {
    persisted = document.copy();
  }
}
