## 0.1.0

First release.

- `ThemeFlow`: light and dark themes from a palette, or from your existing
  `ThemeData` (`base:`), kept untouched in light mode.
- Auto-dark and auto-light derivation in OKLCH, with a WCAG 2.2 contrast pass
  on every derived color. `DarkStyle` with tinted, neutral and black surfaces.
- `recolor`: carries every color of all 47 Material component themes into
  another palette, keeping fonts, shapes and spacing.
- 48 palette tokens (`context.palette`), `ColorToken` for your own colors,
  and `ContrastReport`.
- `ThemeFlowController`: saved choice (shared_preferences by default,
  pluggable `ThemeFlowStorage`), no-flash `load()`, system mode following.
  Controlled mode for apps that keep the mode in their own state.
- Toggles: `ThemeModeBuilder`, `ThemeModeSwitch`, `ThemeModeSwitchTile`,
  `ThemeModeButton`, `ThemeModeSegmented`, `ThemeModeRadios`, `ThemeModeMenu`.
- `ForceBrightness`, `PaletteOverride`, `ThemedImage`, `context.pick`,
  `context.isDark`, and status/navigation bar styling.
