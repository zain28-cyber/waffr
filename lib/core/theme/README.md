# lib/core/theme

Design tokens and the Material theme. Widgets read tokens from here instead
of writing color values, durations or curves inline.

| File | Contents |
| --- | --- |
| `app_color.dart` | `AppColors`: the raw light/dark tokens (background, surface, text, accent, on-accent, destructive, warning) plus `onAccentOf` / `warningOf` / `destructiveOf(context)`. The values here are the source of truth. |
| `app_palette.dart` | `AppPalette.of(context)`: the light or dark token set for the current brightness (`AppPalette.light` / `.dark`). |
| `app_theme.dart` | `AppTheme.lightTheme` / `.darkTheme`: `ThemeData` with Outfit as the primary font and Tajawal as the Arabic fallback, color scheme, switch, text and app bar themes, page transitions. |
| `app_motion.dart` | `AppMotion` (durations `instant`..`countUp`, curves `enter`/`exit`/`standard`/`overshoot`/`soft`, `reduced()`, `enabled()`, `of()`), `AppMotionPaging` on `PageController`, `AppHaptics`, `ReducedMotionPageTransitionsBuilder`. |

How it connects:

- `main.dart` passes `AppTheme.lightTheme` / `darkTheme` to `MaterialApp`
  and uses `AppColors` for the system navigation bar.
- Almost every widget and screen calls `AppPalette.of(context)` for colors;
  the motion widgets in `lib/widgets/motion/` take their timings from `AppMotion`.

Conventions:

- Use `AppPalette.of(context)` for "the current accent"; reach for
  `AppColors` only for tokens the palette does not carry (warning,
  destructive) or outside a `BuildContext`.
- Respect reduced motion: wrap durations in `AppMotion.of(context, ...)`,
  and gate repeating effects on `AppMotion.enabled(context)`, which is also
  false when the enclosing `TickerMode` is off (a hidden tab or the app lock).
- Page pagers step with `nextPageFor` / `previousPageFor` so reduced motion
  jumps instead of sliding.
- Haptics go through `AppHaptics` (selection / success / warning).
