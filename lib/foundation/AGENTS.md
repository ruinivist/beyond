# Foundation Widget Guidance

- Keep widgets generic, app-agnostic, and suitable for later extraction into a standalone package.
- Do not import app theme tokens or other app-specific styling. Accept required colors and styling through the widget API, as Flutter's built-in widgets do.
- Expose only parameters needed by current call sites; do not add speculative configuration.
- Prefer small, composable widgets and Flutter platform primitives over broad abstractions.
