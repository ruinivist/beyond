# Foundation Widget Guidance

- Keep widgets specific to this app; standalone extraction is not a design goal.
- Read semantic values from `BTheme.of(context)` internally.
- Keep concrete palettes, fonts, and syntax themes out of foundation.
- Expose behavior parameters needed by current call sites, but no speculative visual overrides.
- Prefer small, composable widgets and Flutter platform primitives over broad abstractions.
