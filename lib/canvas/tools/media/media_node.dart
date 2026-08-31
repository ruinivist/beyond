import 'dart:math' as math;

import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_element_model.dart';
import 'package:beyond/foundation/control_surface.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const mediaUrlPanelSize = Size(400, 96);

class MediaModel extends CanvasElementModel<MediaElementData> {
  MediaModel(MediaElementData data) : super(data) {
    controller = TextEditingController(text: data.url)..addListener(_syncUrl);
    _loadImage();
  }

  late final TextEditingController controller;
  final focusNode = FocusNode();
  final layerLink = LayerLink();
  NetworkImage? _image;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  double? _aspectRatio;
  var _active = false;

  NetworkImage? get image => _image;

  bool get hasImage => _image != null && _aspectRatio != null;

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
      : mediaUrlPanelSize;

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
    final uri = Uri.tryParse(source);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host.contains('%') ||
        RegExp(r'\s').hasMatch(source)) {
      return;
    }

    final image = NetworkImage(source);
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
          child: OverlayPortal(
            controller: _portalController,
            overlayChildBuilder: (context) => model.active
                ? Positioned(
                    width: mediaUrlPanelSize.width,
                    height: mediaUrlPanelSize.height,
                    child: CompositedTransformFollower(
                      link: model.layerLink,
                      showWhenUnlinked: false,
                      targetAnchor: Alignment.bottomCenter,
                      followerAnchor: Alignment.topCenter,
                      offset: const Offset(0, 16),
                      child: TapRegion(
                        groupId: model,
                        child: _MediaUrlPanel(
                          key: _panelKey,
                          model: model,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            child: model.hasImage
                ? TapRegion(
                    groupId: model,
                    onTapOutside: (_) => model.active = false,
                    child: CompositedTransformTarget(
                      link: model.layerLink,
                      child: _MediaImage(
                        model: model,
                        onMove: widget.onMove,
                        onResize: widget.onResize,
                      ),
                    ),
                  )
                : _MediaUrlPanel(
                    key: _panelKey,
                    model: model,
                    onMove: widget.onMove,
                  ),
          ),
        );
      },
    );
  }
}

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
                child: _MediaResizeHandle(onResize: onResize),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaResizeHandle extends StatelessWidget {
  const _MediaResizeHandle({required this.onResize});

  final ValueChanged<Offset> onResize;

  @override
  Widget build(BuildContext context) {
    final colors = BTheme.of(context).colors;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: RawGestureDetector(
        key: const ValueKey('media-resize-handle'),
        behavior: HitTestBehavior.opaque,
        gestures: {
          ImmediateMultiDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                ImmediateMultiDragGestureRecognizer
              >(ImmediateMultiDragGestureRecognizer.new, (recognizer) {
                recognizer.onStart = (_) => _MediaDrag(onResize);
              }),
        },
        child: ControlSurface(
          child: SizedBox.square(
            dimension: 28,
            child: Icon(
              Icons.open_in_full,
              size: 16,
              color: colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaUrlPanel extends StatelessWidget {
  const _MediaUrlPanel({required this.model, this.onMove, super.key});

  final MediaModel model;
  final ValueChanged<Offset>? onMove;

  @override
  Widget build(BuildContext context) {
    final theme = BTheme.of(context);
    final colors = theme.colors;
    return SizedBox.fromSize(
      key: const ValueKey('media-url-panel'),
      size: mediaUrlPanelSize,
      child: ControlSurface(
        selected: model.selected,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                key: const ValueKey('media-url-field'),
                controller: model.controller,
                focusNode: model.focusNode,
                expands: true,
                maxLines: null,
                keyboardType: TextInputType.url,
                cursorColor: colors.accent,
                style: theme.typo.body.copyWith(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Image URL',
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.all(10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: theme.geo.radiusSmall,
                    borderSide: BorderSide(color: colors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: theme.geo.radiusSmall,
                    borderSide: BorderSide(color: colors.focusRing),
                  ),
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
