# Decisions

- Use `scroll_animator` `0.3.0` with `ChromiumEaseInOut` for smooth pointer scrolling; fork and modernize the dormant package as technical debt.

- Put generic custom widgets in `lib/foundation/`, with semantic `BTheme` values read internally and nullable individual styling parameters overriding them like Flutter widgets.
- Keep concrete Starless Light palette, typography, and syntax theme in the app theme; keep component geometry local to each app component.
