# Interaction Model

Text, code, and media blocks share three independent interaction states.

| State | Meaning | Behavior |
| --- | --- | --- |
| Inactive | A normal canvas object | Content is not editable. Clicking activates the block; dragging moves it without activating it. Options, transform controls, and resize handles are hidden. |
| Active | The primary object being worked on | Options and move, rotate, delete, and resize controls are available. |
| Selected | Part of the canvas selection | The block receives an accent highlight and participates in group movement without becoming active or editable. |

The important distinction is:

- **Active** owns options and controls.
- **Selected** owns group operations.
- **Editing** owns keyboard input.

Text can remain active without being edited. For code, active currently also means editable.

Shapes follow the same state separation: clicking or creating a shape makes it active without selecting it. Ctrl-click, Cmd-click, or marquee selection can select a shape without making it active. An active shape may also be selected, but changing either state does not change the other.

## Text blocks

- Clicking the preview makes the block active, opens the Markdown source editor, and focuses it.
- Dragging the preview moves the block without activating it.
- Using an option or starting a move or rotation closes the source editor but leaves the block active. Options and transform controls remain available.
- Resizing is available whenever the block is active, including while editing.
- Clicking empty canvas or another block, changing tools, or pressing Escape returns the block to its inactive preview.
- Text options control font, color, and fill visibility.

## Code blocks

- Clicking the read-only code surface or title activates the block and makes its source and title editable.
- Dragging the inactive surface or title moves the block without activating it or leaving a code selection behind.
- The active state exposes the editable source and title, language picker, resize handle, and move, rotate, and delete controls.
- The options panel controls line-number visibility.
- Moving or rotating through the floating controls keeps the block active and editable.
- Clicking away or pressing Escape returns the block to its read-only preview. An empty title is hidden while inactive.

## Media blocks

- Media does not switch between separate preview and editor surfaces: the image remains visible in both inactive and active states.
- Clicking an image activates it and reveals its URL panel, resize handle, and top-left transform controls. Dragging an inactive image moves it without activating it.
- A URL-only media block keeps its URL field visible. While active it exposes move and delete controls; rotation becomes available after an image resolves.
- Moving, rotating, or resizing keeps the block active. Resizing preserves the image aspect ratio and follows the element's rotated axes.
- Clicking empty canvas or another block, changing tools, or pressing Escape deactivates the block and hides its active controls.

## Pen strokes

- The pen remains enabled after each stroke until it is toggled off, another tool is chosen, or Escape is pressed.
- Persisted strokes have no active state, options, or transform controls. Pen options apply only to newly drawn strokes.
- Primary-button dragging moves a stroke directly. Modifier-click and marquee selection are the only ways to select strokes.
- Selected strokes participate in group movement and keyboard deletion.

## Arrows

- Drawing an arrow makes it active and returns to the select tool.
- Arrow options set the color, solid or dashed shaft style, and width for newly drawn arrows.
- Activating an existing arrow exposes the same options; edits affect only that arrow and keep its arrowhead solid.
- An active arrow shows its start, bend, and arrowhead points with Bézier guides. Dragging a point reshapes only that arrow.
- Dashed gaps remain part of the arrow's pointer target.

## Drag and selection rules

- Dragging an inactive, unselected block moves only that block and clears any unrelated selection.
- Dragging any member of a selected group moves the whole group.
- Ctrl-click, or Cmd-click on macOS, toggles selection without activating the block.
- Resizing affects one block and clears group selection.
- Movement remains aligned with screen direction under canvas zoom and element rotation. Screen deltas are converted to canvas coordinates before persistence.
- Transform controls rotate with their block and remain anchored to its top-left corner.
- Scrolling inside bounded text or code content does not pan the canvas.
- Only the primary mouse button performs block interactions; other pointer gestures retain their canvas behavior.

## Canvas files

- Clicking the canvas title opens the file picker; hovering the title reveals its folder path.
- Clicking a canvas saves the current file and opens the chosen one. Each file has separate contents; switching clears undo and selection state.
- Clicking a folder expands or collapses it. Header actions create root-level canvases and folders; right-click a folder to create items inside it.
- Names are edited inline. Enter or clicking away saves; Escape or an empty name cancels, and duplicate sibling names are rejected. Clicking another canvas saves the edit and opens that canvas. Right-click an item to rename or delete it; deletion requires confirmation.
- Drag a file or folder above or below a row to place it beside that item. Drop on the center of a folder row to move inside it. A folder moves with its contents; moves that create a folder cycle or duplicate sibling name are rejected.
- While the picker is open, keyboard input belongs to the picker. Escape, the close button, or clicking outside dismisses it; a pending nonempty name is saved before click-away dismissal, while Escape in a name field cancels only that edit.
- Files, folders, and the last-opened canvas persist in this browser. Failed saves keep the current canvas open and preserve entered names for retry.
- Settings > Data can export or import one canvas, or back up and restore the library as a ZIP containing the folder tree, canvas JSON files, and images. Import confirms replacement of the active canvas; restore validates the ZIP and confirms replacement of the whole library. Canceling either leaves the library unchanged. Restore opens the first canvas by ZIP path; file order is not preserved.
