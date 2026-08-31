import 'dart:math' as math;

import 'package:beyond/canvas/canvas_document.dart';
import 'package:beyond/canvas/canvas_element_model.dart';
import 'package:beyond/foundation/control_surface.dart';
import 'package:beyond/foundation/resize_handle.dart';
import 'package:beyond/foundation/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const mediaUrlPanelMinimumWidth = 280.0;
const _mediaUrlPanelCanvasHeight = 96.0;

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
            overlayChildBuilder: (context) => Positioned(
              width: model.urlPanelWidth,
              child: CompositedTransformFollower(
                link: model.layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomCenter,
                followerAnchor: Alignment.topCenter,
                offset: const Offset(0, 8),
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
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('media-url-panel-hidden'),
                          ),
                  ),
                ),
              ),
            ),
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
  const _MediaUrlPanel({required this.model, this.onMove, super.key});

  final MediaModel model;
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
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                key: const ValueKey('media-url-field'),
                controller: model.controller,
                focusNode: model.focusNode,
                minLines: 1,
                maxLines: 3,
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
