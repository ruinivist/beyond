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

For canvas objects without a distinct primary action, such as shapes, selection is the primary action. A normal click therefore makes the object both active and selected. The states remain independent for group selection: Ctrl-click, Cmd-click, or marquee selection can select an object without making it active.

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

## Drag and selection rules

- Dragging an inactive, unselected block moves only that block and clears any unrelated selection.
- Dragging any member of a selected group moves the whole group.
- Ctrl-click, or Cmd-click on macOS, toggles selection without activating the block.
- Resizing affects one block and clears group selection.
- Movement remains aligned with screen direction under canvas zoom and element rotation. Screen deltas are converted to canvas coordinates before persistence.
- Transform controls rotate with their block and remain anchored to its top-left corner.
- Scrolling inside bounded text or code content does not pan the canvas.
- Only the primary mouse button performs block interactions; other pointer gestures retain their canvas behavior.
