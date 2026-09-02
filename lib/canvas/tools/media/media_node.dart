import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beyond/canvas/attachment_store.dart';
import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_element_model.dart';
import 'package:beyond/foundation/control_surface.dart';
import 'package:beyond/foundation/resize_handle.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

const mediaUrlPanelMinimumWidth = 480.0;
const _mediaUrlPanelCanvasHeight = 48.0;
const _imageTypes = XTypeGroup(
  label: 'images',
  extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
  mimeTypes: ['image/png', 'image/jpeg', 'image/gif', 'image/webp'],
  uniformTypeIdentifiers: [
    'public.png',
    'public.jpeg',
    'com.compuserve.gif',
    'org.webmproject.webp',
  ],
);

bool isSupportedMediaUrl(String source) {
  final uri = Uri.tryParse(source);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      !uri.host.contains('%') &&
      !RegExp(r'\s').hasMatch(source);
}

class MediaModel extends CanvasElementModel<MediaElementData> {
  MediaModel(MediaElementData data, this.attachmentStore) : super(data) {
    controller = TextEditingController(text: data.url)..addListener(_syncUrl);
    _loadImage();
  }

  final AttachmentStore attachmentStore;
  late final TextEditingController controller;
  final focusNode = FocusNode();
  ImageProvider<Object>? _image;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Object? _attachmentLoad;
  double? _aspectRatio;
  var _active = false;

  ImageProvider<Object>? get image => _image;

  bool get hasImage => _image != null && _aspectRatio != null;

  double get urlPanelWidth => hasImage
      ? math.max(mediaUrlPanelMinimumWidth, data.width)
      : mediaUrlPanelMinimumWidth;

  bool get active => _active;

  set active(bool value) {
    final next = value && hasImage;
    if (_active == next) return;
    _active = next;
    notifyListeners();
  }

  @override
  Offset get canvasPosition => data.position;

  @override
  Size get canvasSize => hasImage
      ? Size(data.width, data.width / _aspectRatio!)
      : Size(urlPanelWidth, _mediaUrlPanelCanvasHeight);

  @override
  void moveBy(Offset delta) {
    if (delta == Offset.zero) return;
    data.position += delta;
    notifyListeners();
  }

  void resizeBy(Offset delta) {
    final aspectRatio = _aspectRatio;
    if (aspectRatio == null) return;
    final inverseRatio = 1 / aspectRatio;
    final widthDelta =
        (delta.dx + delta.dy * inverseRatio) /
        (1 + inverseRatio * inverseRatio);
    final width = math.max(mediaNodeMinimumWidth, data.width + widthDelta);
    if (width == data.width) return;
    data.width = width;
    notifyListeners();
  }

  Future<void> setDeviceImage(Uint8List bytes, String extension) async {
    final normalizedExtension = extension.toLowerCase() == 'jpeg'
        ? 'jpg'
        : extension.toLowerCase();
    if (!const {'png', 'jpg', 'gif', 'webp'}.contains(normalizedExtension)) {
      throw const FormatException('Unsupported image type');
    }
    if (bytes.length > attachmentMaximumBytes) {
      throw const FormatException('Image exceeds 10 MiB');
    }

    final path = 'attachments/${const Uuid().v4()}.$normalizedExtension';
    final ratio = await _imageAspectRatio(bytes);
    await attachmentStore.write(path, bytes);

    data.url = path;
    controller.text = path;
    _detachImage();
    _image = MemoryImage(bytes);
    _aspectRatio = ratio;
    _active = true;
    notifyListeners();
  }

  void _syncUrl() {
    if (data.url == controller.text) return;
    data.url = controller.text;
    _active = false;
    _loadImage();
    notifyListeners();
  }

  void _loadImage() {
    _detachImage();
    final source = data.url.trim();
    if (attachmentPathPattern.hasMatch(source)) {
      final load = Object();
      _attachmentLoad = load;
      unawaited(_loadAttachment(source, load));
      return;
    }
    if (!isSupportedMediaUrl(source)) return;

    _attachImage(NetworkImage(source));
  }

  Future<void> _loadAttachment(String path, Object load) async {
    try {
      final bytes = await attachmentStore.read(path);
      if (_attachmentLoad != load) return;
      _attachImage(MemoryImage(bytes));
    } on Object {
      if (_attachmentLoad != load) return;
      _active = false;
      notifyListeners();
    }
  }

  void _attachImage(ImageProvider<Object> image) {
    final stream = image.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        final ratio = info.image.width / info.image.height;
        if (_aspectRatio == ratio && _image == image) return;
        _image = image;
        _aspectRatio = ratio;
        _active = focusNode.hasFocus;
        notifyListeners();
      },
      onError: (_, _) {
        _image = null;
        _aspectRatio = null;
        _active = false;
        notifyListeners();
      },
    );
    _image = image;
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _detachImage() {
    final stream = _imageStream;
    final listener = _imageListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _imageStream = null;
    _imageListener = null;
    _attachmentLoad = null;
    _image = null;
    _aspectRatio = null;
  }

  @override
  void dispose() {
    _detachImage();
    controller
      ..removeListener(_syncUrl)
      ..dispose();
    focusNode.dispose();
    super.dispose();
  }
}

class MediaNode extends StatefulWidget {
  const MediaNode({
    required this.model,
    required this.onMove,
    required this.onResize,
    super.key,
  });

  final MediaModel model;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;

  @override
  State<MediaNode> createState() => _MediaNodeState();
}

class _MediaNodeState extends State<MediaNode> {
  final _portalController = OverlayPortalController();
  final Key _panelKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portalController.show();
    });
  }

  Future<void> _pickImage() async {
    try {
      final file = await openFile(acceptedTypeGroups: const [_imageTypes]);
      if (file == null) return;
      final separator = file.name.lastIndexOf('.');
      if (separator < 0) throw const FormatException('Missing image type');
      if (await file.length() > attachmentMaximumBytes) {
        throw const FormatException('Image exceeds 10 MiB');
      }
      await widget.model.setDeviceImage(
        await file.readAsBytes(),
        file.name.substring(separator + 1),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open image')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) {
        final model = widget.model;
        return Semantics(
          container: true,
          image: model.hasImage,
          selected: model.selected,
          label: model.hasImage ? 'Image media' : 'Image URL',
          child: OverlayPortal.overlayChildLayoutBuilder(
            controller: _portalController,
            overlayChildBuilder: (context, layout) {
              final panelWidth = model.urlPanelWidth;
              return Positioned(
                left: 0,
                top: 0,
                child: Transform(
                  transform: layout.childPaintTransform,
                  alignment: Alignment.topLeft,
                  child: Transform.translate(
                    offset: Offset(
                      (layout.childSize.width - panelWidth) / 2,
                      layout.childSize.height + 8,
                    ),
                    child: SizedBox(
                      width: panelWidth,
                      child: IgnorePointer(
                        ignoring: !model.active,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          reverseDuration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          transitionBuilder: _mediaUrlPanelTransition,
                          child: model.active
                              ? TapRegion(
                                  groupId: model,
                                  child: _MediaUrlPanel(
                                    key: _panelKey,
                                    model: model,
                                    onPickImage: _pickImage,
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('media-url-panel-hidden'),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: model.hasImage
                ? TapRegion(
                    groupId: model,
                    onTapOutside: (_) => model.active = false,
                    child: _MediaImage(
                      model: model,
                      onMove: widget.onMove,
                      onResize: widget.onResize,
                    ),
                  )
                : _MediaUrlPanel(
                    key: _panelKey,
                    model: model,
                    onMove: widget.onMove,
                    onPickImage: _pickImage,
                  ),
          ),
        );
      },
    );
  }
}

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

class _MediaImage extends StatelessWidget {
  const _MediaImage({
    required this.model,
    required this.onMove,
    required this.onResize,
  });

  final MediaModel model;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    final image = model.image!;
    return SizedBox.fromSize(
      size: model.canvasSize,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          ImmediateMultiDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                ImmediateMultiDragGestureRecognizer
              >(ImmediateMultiDragGestureRecognizer.new, (recognizer) {
                recognizer.onStart = (_) => _MediaDrag(onMove);
              }),
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: theme.geo.radiusSmall,
                child: Image(
                  key: const ValueKey('media-image'),
                  image: image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (model.selected)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: theme.geo.radiusSmall,
                      border: Border.all(color: colors.accent, width: 2),
                    ),
                  ),
                ),
              ),
            if (model.active)
              Positioned(
                right: 0,
                bottom: 0,
                child: ResizeHandle(
                  key: const ValueKey('media-resize-handle'),
                  semanticLabel: 'Resize media',
                  gestures: {
                    ImmediateMultiDragGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          ImmediateMultiDragGestureRecognizer
                        >(
                          ImmediateMultiDragGestureRecognizer.new,
                          (recognizer) {
                            recognizer.onStart = (_) => _MediaDrag(onResize);
                          },
                        ),
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaUrlPanel extends StatelessWidget {
  const _MediaUrlPanel({
    required this.model,
    required this.onPickImage,
    this.onMove,
    super.key,
  });

  final MediaModel model;
  final VoidCallback onPickImage;
  final ValueChanged<Offset>? onMove;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    return SizedBox(
      key: const ValueKey('media-url-panel'),
      width: model.urlPanelWidth,
      child: ControlSurface(
        selected: model.selected,
        child: Stack(
          children: [
            TextField(
              key: const ValueKey('media-url-field'),
              controller: model.controller,
              focusNode: model.focusNode,
              minLines: 1,
              maxLines: 3,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: TextInputType.url,
              cursorColor: colors.accent,
              style: theme.typo.body.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Image URL',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                suffixIcon: IconButton(
                  key: const ValueKey('media-device-picker'),
                  tooltip: 'Choose image from device',
                  onPressed: onPickImage,
                  icon: const Icon(LucideIcons.imageUp, size: 20),
                ),
              ),
            ),
            if (onMove case final move?)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 8,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: RawGestureDetector(
                    key: const ValueKey('media-panel-drag-strip'),
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      ImmediateMultiDragGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            ImmediateMultiDragGestureRecognizer
                          >(
                            ImmediateMultiDragGestureRecognizer.new,
                            (recognizer) {
                              recognizer.onStart = (_) => _MediaDrag(move);
                            },
                          ),
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaDrag extends Drag {
  _MediaDrag(this.onUpdate);

  final ValueChanged<Offset> onUpdate;

  @override
  void update(DragUpdateDetails details) => onUpdate(details.delta);
}

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
