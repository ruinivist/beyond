# Decisions

- Use `scroll_animator` `0.3.0` with `ChromiumEaseInOut` for smooth pointer scrolling; fork and modernize the dormant package as technical debt.

- Put generic custom widgets in `lib/foundation/`, keeping them independent of app theme tokens and suitable for later package extraction.
  Pass required colors and styling at call sites, and add API parameters only when current uses need them.
