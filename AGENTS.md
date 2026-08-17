# Project Guidance

- This is an infinite canvas project under active development.
- Backward compatibility is not required yet.
- Prefer globally coherent, root-cause changes over local patches, even when they require breaking changes.
- Use packages that are available on all platforms but only test build for "web", no need to test for any others at this stage.

# UI Decisions

- Use `scroll_animator` `0.3.0` with `ChromiumEaseInOut` for smooth pointer scrolling
- Put reusable app-specific widgets in `lib/foundation/` and read semantic `BTheme` values internally.
- Do not expose visual overrides until a concrete product requirement justifies an explicit semantic API.
- Keep concrete Starless Light palette, typography, syntax theme, and reusable geometry in the app theme; keep component-specific geometry local to each component.

# Testing guidance

- Only test for "behavior" and not UI token values as such token values can change anytime; behavior like so and so tokens should exist is correct but matchin them against a constant is wrong.
- Keep testing lighter, we'll add tests once we have something concrete but NOT at this stage.
