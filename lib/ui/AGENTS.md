# UI Guidance

- Keep app-wide Flutter primitives in `common/`; standalone extraction is not a design goal.
- Keep feature-specific widgets with their owning feature.
- Read semantic values from `BTheme.of(context)` internally.
- Keep concrete palettes, fonts, and syntax themes out of `ui/`.
- Expose behavior parameters needed by current call sites, but no speculative visual overrides.
- Prefer small, composable widgets and Flutter platform primitives over broad abstractions.

## Naming convention

- `B` is the Beyond app prefix.
- Follow it with the visual type, then the action the widget is most commonly intended for, such as `BIconDrag`.
