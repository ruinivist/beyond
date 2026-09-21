// Verifies controlled disclosure and action routing in the file-tree popup.
// Exercises the canvas popup independently of document persistence.

import 'package:beyond/canvas/editor/widgets/file_tree_popup.dart';
import 'package:beyond/theme/starless.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------- Tests ----------

void main() {
  testWidgets('routes tree and popup actions', (tester) async {
    const nodes = [
      FileTreeNode(
        id: 'projects',
        name: 'Projects',
        type: FileTreeNodeType.folder,
        children: [
          FileTreeNode(id: 'brainstorm', name: 'Brainstorm', type: FileTreeNodeType.file),
        ],
      ),
    ];
    final expandedIds = {'projects'};
    String? selectedId;
    String? contextId;
    var newFolderCalls = 0;
    var closeCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: starlessLightThemeData,
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => FileTreePopup(
                nodes: nodes,
                selectedId: selectedId,
                expandedIds: expandedIds,
                onSelect: (node) => setState(() => selectedId = node.id),
                onToggle: (folder) => setState(() {
                  if (!expandedIds.remove(folder.id)) expandedIds.add(folder.id);
                }),
                onNewFolder: () => newFolderCalls++,
                onClose: () => closeCalls++,
                onContextMenu: (node, _) => contextId = node.id,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Brainstorm'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('file-tree-node-projects')));
    await tester.pump();
    expect(find.text('Brainstorm'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('file-tree-node-projects')));
    await tester.pump();
    await tester.tap(find.text('Brainstorm'));
    await tester.pump();
    expect(selectedId, 'brainstorm');

    await tester.tap(
      find.byKey(const ValueKey('file-tree-node-brainstorm')),
      buttons: kSecondaryMouseButton,
    );
    expect(contextId, 'brainstorm');

    await tester.tap(find.byKey(const ValueKey('file-tree-new-folder')));
    await tester.tap(find.byKey(const ValueKey('file-tree-close')));
    expect(newFolderCalls, 1);
    expect(closeCalls, 1);
  });
}
