// Provides shared media transitions, drag handling, and image decoding.
// Used by the media tool, image surface, URL panel, and media model.

part of 'media_tool.dart';

// ---------- Transitions ----------

Widget _mediaUrlPanelTransition(
  Widget child,
  Animation<double> animation,
) => FadeTransition(
  opacity: animation,
  child: ScaleTransition(
    scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
    alignment: Alignment.topCenter,
    child: child,
  ),
);

// ---------- Gestures ----------

class _MediaDrag extends Drag {
  _MediaDrag(this.onUpdate);

  final ValueChanged<Offset> onUpdate;

  @override
  void update(DragUpdateDetails details) => onUpdate(details.delta);
}

// ---------- Image decoding ----------

Future<double> _imageAspectRatio(Uint8List bytes) async {
  ui.Codec? codec;
  ui.FrameInfo? frame;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    frame = await codec.getNextFrame();
    return frame.image.width / frame.image.height;
  } catch (error) {
    throw FormatException('Invalid encoded image: $error');
  } finally {
    frame?.image.dispose();
    codec?.dispose();
  }
}
