# themeflow

**Dark mode for an existing Flutter app in an afternoon, and a clean theming setup for new ones.**

Give themeflow the light theme you already have. Light mode stays exactly that
theme. Dark mode is the same theme, recolored, with your fonts, shapes and
spacing kept and every color checked for contrast. You also get typed color
tokens, a saved user choice and ready-made toggles.

- **Keeps your theme.** Pass your `ThemeData`; light mode is untouched.
- **Derives dark for you.** Brand, surfaces, text, borders and status colors
  are carried over by what they're for, then contrast-checked against WCAG 2.2.
- **Covers all of Material.** Every color in all 47 component themes is
  recolored, and a test fails if Flutter adds one themeflow doesn't know.
- **Typed tokens, no codegen.** `context.palette.surface`, plus your own
  `ColorToken`s that still work as plain colors while you migrate.
- **Any architecture.** A plain `ChangeNotifier`, or drive it from your own
  cubit, provider or GetX state.
- **Any toggle.** Switch, settings row, icon button, segmented button, radios,
  menu, or a builder for your own design.
- **No flash at launch**, live updates in open dialogs and sheets, and status
  bar icons that match.

## Install

```bash
flutter pub add themeflow
```

## An existing app

Wrap your app and pass your current theme as `base`:

```dart
final theme = ThemeFlowController(); // saves the choice with shared_preferences

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await theme.load(); // read the saved choice before the first frame
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeFlow(
      controller: theme,
      base: AppTheme.light, // your ThemeData, untouched in light mode
      builder: (context, t) => MaterialApp(
        theme: t.light,
        darkTheme: t.dark,
        themeMode: t.mode,
        home: const HomePage(),
      ),
    );
  }
}
```

Then put a toggle somewhere:

```dart
const ThemeModeSwitchTile(); // a settings row: "Dark mode"
```

That's a working dark mode. Widgets that read `Theme.of(context)` follow it
straight away. Colors hardcoded in widgets don't (no package can change those
safely), so the next step is moving them to tokens, one screen at a time.

## A new app

Give a palette instead. One brand color is enough:

```dart
ThemeFlow(
  controller: theme,
  light: const ThemePalette(primary: Color(0xFF3D5AFE)),
  builder: (context, t) => MaterialApp(
    theme: t.light,
    darkTheme: t.dark,
    themeMode: t.mode,
    home: const HomePage(),
  ),
);
```

Set more tokens when you care about them (`background`, `text`, `success`…).
A `dark:` palette works as overrides on top of the derived dark colors, so it
can be as small as one color:

```dart
ThemeFlow(
  light: const ThemePalette(primary: brand, background: Color(0xFFF7F7F5)),
  dark: const ThemePalette(background: Color(0xFF000000)),
  // ...
);
```

Other ways to make a palette: `ThemePalette.seed(color)` (Material 3 tonal
palette from Flutter's own `ColorScheme.fromSeed`), `ThemePalette.fromTheme`,
and `ThemePalette.fromColorScheme` (for example with `dynamic_color`).

Palettes are `ThemeFlow` parameters, so hot reload shows a color change in
both modes at once.

## Reading colors

```dart
Container(color: context.palette.surface);
Text('Due tomorrow', style: TextStyle(color: context.palette.textSecondary));
```

48 tokens, grouped:

| Group | Tokens |
|---|---|
| Brand | `primary`, `secondary`, `tertiary`, each with `on…`, `…Container`, `on…Container` |
| Surfaces | `background`, `surface` (cards), `surfaceElevated` (dialogs, menus), `fill` (inputs), `inverseSurface`, `onInverseSurface` |
| Content | `text`, `textSecondary`, `textTertiary`, `textDisabled`, `link` |
| Lines | `border`, `divider`, `focus` |
| Status | `error`, `success`, `warning`, `info`, each with `on…`, `…Container`, `on…Container` |
| Effects | `overlay`, `selection`, `skeleton`, `skeletonHighlight`, `scrim`, `shadow` |

Every `ColorScheme` role is filled in too, so Material widgets match.

### Your own colors

```dart
abstract final class AppColors {
  static const gold = ColorToken(0xFFC9A227, id: 'gold'); // dark is derived
  static const page = ColorToken(0xFFF4ECD8, id: 'page',
      role: TokenRole.surface, dark: Color(0xFF1E1A14));    // dark is given
}

Icon(Icons.star, color: AppColors.gold.of(context));
```

A `ColorToken` is a `Color` whose value is the light color, so existing code
that uses `AppColors.gold` keeps compiling and looks as it did. Add
`.of(context)` call site by call site.

### One-off values

```dart
final art = context.pick(light: 'assets/empty_light.png', dark: 'assets/empty_dark.png');
```

`context.isDark` and `context.pick` are correct in system mode, unlike
`MediaQuery.platformBrightnessOf`, which ignores the user's choice.

## Toggles

All of them read and change the nearest `ThemeFlow`.

| Widget | What it is |
|---|---|
| `ThemeModeBuilder` | Headless: gives you `mode`, `isDark`, `setMode`, `toggle`, `cycle` to wrap your own control |
| `ThemeModeSwitch` | A switch; on means dark |
| `ThemeModeSwitchTile` | A settings row with that switch |
| `ThemeModeButton` | An icon button with an animated sun and moon; `cycle: true` adds system |
| `ThemeModeSegmented` | System / Light / Dark |
| `ThemeModeRadios` | A radio list for settings screens |
| `ThemeModeMenu` | An icon button with a menu |

From code: `context.themeFlow.setMode(ThemeMode.dark)`, or call the controller.
Text is English by default; translate it with `ThemeFlow(labels: ThemeFlowLabels(...))`.

## Your own state

Already keep the mode in a cubit or provider? Skip the controller:

```dart
ThemeFlow(
  mode: state.themeMode,
  onModeChanged: cubit.setThemeMode, // the toggles call this
  base: AppTheme.light,
  builder: (context, t) => MaterialApp(theme: t.light, darkTheme: t.dark, themeMode: t.mode),
);
```

Or keep the controller and change where it saves: `ThemeFlowStorage` has two
methods, `read` and `write`, so Hive, secure storage or a server work too.
`ThemeFlowStorage.none` saves nothing.

## How dark is derived

- A color you set is never changed.
- A color you didn't set is carried over by its role. Surfaces turn dark and
  get a little lighter with elevation. Text turns light. Brand and status
  colors get lighter and slightly calmer. Containers become dark tints.
- Then every derived foreground is moved in lightness, by the smallest
  amount, until it reaches its WCAG 2.2 minimum: 4.5:1 for text and `on…`
  colors, 3:1 for borders, accents and tertiary text.

Color math uses OKLCH, so equal lightness looks equally light across hues.
`DarkStyle(surfaces: DarkSurfaces.neutral)` gives pure greys, and
`DarkSurfaces.black` gives a black background for OLED screens.

In debug builds, colors you set that are hard to read are printed with a
suggested fix. Keep it that way with a test:

```dart
test('palette stays readable', () {
  final p = resolvePalettes(light: AppPalette.light);
  expect(p.light.contrastReport().failures, isEmpty);
  expect(p.dark.contrastReport().failures, isEmpty);
});
```

## Escape hatches

- `ForceBrightness.dark(child: ...)` shows a subtree in the dark theme
  whatever the mode: video players, photo viewers.
- `PaletteOverride(colors: {...}, update: (p) => p.copyWith(...), child: ...)`
  changes palette colors for a subtree. Material widgets inside follow.
- `ThemedImage(light:, dark:)` swaps images; `ThemedImage.dimmed(image:)`
  gently dims photos with white backgrounds in dark mode.
- Your own `ThemeExtension`s can implement `Recolorable` to be carried into
  dark too, or you pass dark versions with `darkExtensions:`.
- `ThemeFlow(enabled: false)` always shows your light theme and hides the
  toggles, for rolling dark mode out behind a flag.
- `systemBars: false` stops themeflow styling the status and navigation bars.

## What themeflow changes, and doesn't

- With a `base`, light mode is your `ThemeData` plus one `ThemeExtension`.
  Nothing else changes, and a test checks that.
- `setMode(ThemeMode.light)` shows your original theme; `reset()` also clears
  the saved choice.
- The only global effect is one `AnnotatedRegion` for the system bars.
- Dependencies: `flutter` and `shared_preferences`. No codegen, no
  singletons.
- Storage errors and color problems never throw.

## Requirements

Flutter 3.44 or later. Older versions will be added once CI has verified them.

## Roadmap

- **0.2**: `themeflow_audit`, a command that lists the hardcoded colors left
  in your code and suggests the token for each.
- **0.3**: variants (Sepia, Black), separately themed areas such as a reader,
  user-picked accent colors, an in-app inspector, high-contrast themes.
- **1.0**: automatic fixes, lints, and a stable API.

## License

MIT
