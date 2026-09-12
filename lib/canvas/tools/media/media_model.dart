// Owns media source resolution, sizing, activation, and persisted state.
// Used by the media tool, attachment storage, and canvas persistence flows.

part of 'media_tool.dart';

// ---------- Models ----------

/// Owns media loading state and synchronizes it with persisted element data.
/// Used by media rendering, editing, resizing, and attachment storage.
class MediaModel extends CanvasElementModel<MediaElementData> {
  // ---------- Construction ----------

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

  // ---------- State and geometry ----------

  ImageProvider<Object>? get image => _image;

  bool get hasImage => _image != null && _aspectRatio != null;

  double get urlPanelWidth => hasImage ? math.max(mediaUrlPanelMinimumWidth, data.width) : mediaUrlPanelMinimumWidth;

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
  Size get canvasSize =>
      hasImage ? Size(data.width, data.width / _aspectRatio!) : Size(urlPanelWidth, _mediaUrlPanelCanvasHeight);

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
    final widthDelta = (delta.dx + delta.dy * inverseRatio) / (1 + inverseRatio * inverseRatio);
    final width = math.max(mediaNodeMinimumWidth, data.width + widthDelta);
    if (width == data.width) return;
    data.width = width;
    notifyListeners();
  }

  // ---------- Image updates ----------

  Future<void> setDeviceImage(Uint8List bytes, String extension) async {
    final normalizedExtension = extension.toLowerCase() == 'jpeg' ? 'jpg' : extension.toLowerCase();
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

  // ---------- Private helpers ----------

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

  // ---------- Lifecycle ----------

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
