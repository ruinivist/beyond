// Provides media import, storage, sizing, rendering, and interaction.
// Used by the canvas media tool and persisted media elements.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beyond/canvas/document/canvas_document.dart';
import 'package:beyond/canvas/editor/canvas_element_model.dart';
import 'package:beyond/canvas/editor/widgets/resize_handle.dart';
import 'package:beyond/canvas/persistence/attachments/store.dart';
import 'package:beyond/ui/common/b_container.dart';
import 'package:beyond/ui/theme.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

part 'media_image.dart';
part 'media_model.dart';
part 'media_source.dart';
part 'media_tool_helpers.dart';
part 'media_url_panel.dart';

// ---------- Media tool ----------

/// Renders a media element or its URL entry panel.
/// Used by the canvas element stack for persisted media models.
class MediaTool extends StatefulWidget {
  const MediaTool({
    required this.model,
    required this.onMove,
    required this.onResize,
    super.key,
  });

  final MediaModel model;
  final ValueChanged<Offset> onMove;
  final ValueChanged<Offset> onResize;

  @override
  State<MediaTool> createState() => _MediaToolState();
}

class _MediaToolState extends State<MediaTool> {
  // ---------- State ----------

  final _portalController = OverlayPortalController();
  final Key _panelKey = GlobalKey();

  // ---------- Lifecycle and actions ----------

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

  // ---------- Rendering ----------

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
