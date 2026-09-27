# UI Guidance

- Keep app-wide Flutter primitives in `common/`; standalone extraction is not a design goal.
- Keep feature-specific widgets with their owning feature.
- Read semantic values from `BTheme.of(context)` internally.
- Keep concrete palettes, fonts, and syntax themes out of `ui/`.
- Expose behavior parameters needed by current call sites, but no speculative visual overrides.
- Prefer small, composable widgets and Flutter platform primitives over broad abstractions.
- Give every reusable UI widget its own annotated preview in `previews/`.

## Naming convention

- Name shared widgets by their role, such as `SurfaceIconButton` or `LabeledSwitch`.
- Use an import alias when a real name collision occurs.
