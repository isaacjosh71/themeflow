# themeflow example

An "existing app" whose light theme (`lib/app_theme.dart`) knows nothing about
dark mode. `lib/main.dart` wraps it in `ThemeFlow(base: AppTheme.light(...))`,
and that one wrapper gives it a contrast-checked dark theme.

- **Components** shows common Material widgets, custom `ColorToken`s, status
  banners, a dialog, a snackbar, and a bottom sheet you can switch modes from
  while it's open.
- **Tokens** lists all 48 palette tokens with their values and the contrast
  report.
- **Settings** has every ready-made toggle, plus demo knobs: start from the
  existing theme or from a brand color, pick the brand color, and pick dark
  surfaces (tinted, neutral, black).

```bash
flutter run
```
