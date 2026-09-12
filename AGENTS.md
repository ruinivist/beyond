# Project Guidance

- This is an infinite canvas project under active development.
- Backward compatibility is not required yet.
- Prefer globally coherent, root-cause changes over local patches, even when they require breaking changes.
- Use packages that are available on all platforms but only test build for "web", no need to test for any others at this stage.

# UI Decisions

- Use `scroll_animator` `0.3.0` with `ChromiumEaseInOut` for smooth pointer scrolling
- Put app-wide Flutter primitives in `lib/ui/common/` and read semantic `BTheme` values internally.
- Keep canvas-specific widgets in `lib/canvas/editor/widgets/`.
- Do not expose visual overrides until a concrete product requirement justifies an explicit semantic API.
- Keep concrete Starless Light palette, typography, syntax theme, and reusable geometry in the app theme; keep component-specific geometry local to each componen. Example: instead of hardcoding random number sizes that we are using repeatedly across the app as a "preferred size" make it owned
  by the app. Example something like an icon should be consistent unless component-specific override is needed, so an icons size belongs some place
  in theme but a widget specific larger icon size can be hardcoded inline.

# Testing guidance

- Only test for "behavior" and not UI token values as such token values can change anytime; behavior like so and so tokens should exist is correct but matchin them against a constant is wrong.
- Keep testing lighter, we'll add tests once we have something concrete but NOT at this stage.
- Don't run the FULL test suite for every change, just ONCE before we commit if we added new features/fixes. For styling/refactors, you can skip tests.
