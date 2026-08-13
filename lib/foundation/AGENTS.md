# Foundation Widget Guidance

- Keep widgets generic and suitable for later extraction into a standalone package.
- Read semantic values from `BTheme.of(context)` internally; nullable individual styling parameters override them like Flutter widgets.
- Keep concrete palettes, fonts, and syntax themes out of foundation.
- Expose only parameters needed by current call sites; do not add speculative configuration.
- Prefer small, composable widgets and Flutter platform primitives over broad abstractions.
