# Project Guidance

- This is an infinite canvas project under active development.
- Backward compatibility is not required yet.
- Prefer globally coherent, root-cause changes over local patches, even when they require breaking changes.
- Use packages that are available on all platforms but only test build for "web", no need to test for any others at this stage.

# UI Decisions

- Use `scroll_animator` `0.3.0` with `ChromiumEaseInOut` for smooth pointer scrolling
- Put generic custom widgets in `lib/foundation/`, with semantic `BTheme` values read internally and nullable individual styling parameters overriding them like Flutter widgets.
- Keep concrete Starless Light palette, typography, syntax theme, and reusable geometry in the app theme; keep component-specific geometry local to each component.
