// Previews the canvas file-tree popup with temporary interactive data.
// Used by Flutter widget previews while the popup remains outside the app shell.

import 'package:beyond/canvas/editor/widgets/file_tree_popup.dart';
import 'package:beyond/theme/theme.dart';
import 'package:beyond/ui/previews/theme_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

// ---------- Preview ----------

@Preview(
  name: 'FileTreePopup',
  size: Size(480, 520),
  theme: previewTheme,
  brightness: Brightness.light,
)
Widget fileTreePopupPreview() => const _FileTreePopupPreview();

class _FileTreePopupPreview extends StatefulWidget {
  const _FileTreePopupPreview();

  @override
  State<_FileTreePopupPreview> createState() => _FileTreePopupPreviewState();
}

class _FileTreePopupPreviewState extends State<_FileTreePopupPreview> {
  static const _nodes = [
    FileTreeNode(
      id: 'notes',
      name: 'Notes',
      type: FileTreeNodeType.folder,
      children: [
        FileTreeNode(
          id: 'projects',
          name: 'Projects',
          type: FileTreeNodeType.folder,
          children: [
            FileTreeNode(id: 'brainstorm', name: 'Brainstorm', type: FileTreeNodeType.file),
            FileTreeNode(id: 'design', name: 'Design', type: FileTreeNodeType.file),
            FileTreeNode(id: 'research', name: 'Research', type: FileTreeNodeType.file),
            FileTreeNode(id: 'ideas', name: 'Ideas', type: FileTreeNodeType.file),
          ],
        ),
      ],
    ),
    FileTreeNode(id: 'archive', name: 'Archive', type: FileTreeNodeType.folder),
    FileTreeNode(id: 'personal', name: 'Personal', type: FileTreeNodeType.folder),
    FileTreeNode(id: 'templates', name: 'Templates', type: FileTreeNodeType.folder),
  ];

  String? _selectedId = 'brainstorm';
  final _expandedIds = {'notes', 'projects'};

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BTheme.of(context).colors.canvasBackground,
      child: Center(
        child: FileTreePopup(
          nodes: _nodes,
          selectedId: _selectedId,
          expandedIds: _expandedIds,
          onSelect: (node) => setState(() => _selectedId = node.id),
          onToggle: _toggle,
          onNewFolder: () {},
          onClose: () {},
          onContextMenu: (_, _) {},
        ),
      ),
    );
  }

  void _toggle(FileTreeNode folder) {
    setState(() {
      if (!_expandedIds.remove(folder.id)) _expandedIds.add(folder.id);
    });
  }
}
