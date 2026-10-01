# themeflow: design

> **Status:** v0.1 is built in `packages/themeflow` (2026-10-01). The decisions in §16 were taken as recommended. Where the code differs from this plan, the plan has been updated, and §17 lists what changed.
> The package names `themeflow` and `themeflow_audit` were both free on pub.dev when checked today.

---

## 1. Why

Adding dark mode to a Flutter app that was built light-first takes weeks. We did it on a production reading app, and the same problems came up on every screen:

- Colors are hardcoded everywhere (`Color(0xFF…)`, `Colors.white`, a static `AppColors` class), and each one needs a dark twin.
- `isDark ? a : b` spreads through build methods, and `isDark` gets passed down through constructors.
- `ThemeData` has around 50 component themes. If the light theme styles app bars, buttons, inputs and cards, the dark theme has to be rebuilt by hand, and over time the two drift apart.
- Colors that `ColorScheme` doesn't have (secondary text, borders, success, skeleton loaders) need a `ThemeExtension` with hand-written `copyWith`/`lerp`, or code generation.
- A bottom sheet that worked out its colors before it opened stays light when the user switches to dark from inside it.
- Status-bar icons disappear on screens that have no `AppBar`.
- Illustrations with white backgrounds glow in dark mode.
- The saved choice loads after the first frame, so the app flashes the wrong theme at launch.
- Contrast problems (grey on dark grey) are found late by QA, one screen at a time.

```dart
// What the code ends up looking like…
final isDark = Theme.of(context).brightness == Brightness.dark;
Container(color: isDark ? const Color(0xFF1E1E1E) : Colors.white);

// …and what it should look like
Container(color: context.palette.surface);
```

**What themeflow promises: dark mode for an existing Flutter app in an afternoon, and a clean theming setup for new apps.**

### The brief, and where each point is covered

| Asked for | Covered in |
|---|---|
| Fits any codebase architecture | §8: a plain `ChangeNotifier`, a "controlled mode" that runs on your own state, or pure functions. No codegen. |
| Any toggle: switch, radio, tap | §9.3: a headless builder plus 7 ready-made widgets |
| Add your colors easily and see them right away | §5: 1–6 colors in, 48 tokens out. Hot reload updates both modes; the Inspector (v0.3) edits colors live |
| Doesn't mess up the app | §3: six guarantees, each one backed by a test |
| Switch back to the light theme you had | Guarantee 2: light mode is your original `ThemeData` |
| Takes the tedium out of dark mode | §6 auto-dark, §7 recolor, §10 audit tool |

## 2. What already exists, and the gap

| Package (pub.dev, 2026-10-01) | Likes | Downloads / 30 days | What it does | What it leaves to you |
|---|---|---|---|---|
| flex_color_scheme 9.0.0 | 3,238 | 102,842 | Generates rich light and dark `ThemeData` from schemes or seeds | State, persistence, toggles and custom tokens. It has a large API, can't adopt your existing theme and doesn't find hardcoded colors |
| adaptive_theme 3.8.0 | 955 | 34,070 | Light/dark/system state and persistence | Writing both `ThemeData` by hand. No tokens, no migration help |
| theme_tailor 4.0.1 | 228 | 48,730 | Generates `ThemeExtension` boilerplate | Needs build_runner, and you still pick every dark value |
| animated_theme_switcher 2.0.10 | 532 | 3,378 | Circular reveal animation when switching | Everything except the animation |
| dynamic_color 2.1.0 | 638 | 183,266 | Material You wallpaper colors | It only supplies colors |

No package takes an existing light app all the way to a correct dark mode. That means adopting the theme you already have, deriving the dark side with contrast guaranteed, giving you typed tokens without codegen, handling state and toggles, and finding the hardcoded colors still left in your code. themeflow does all of that.

It also works alongside these packages: a `FlexThemeData` can be the base theme, and `dynamic_color` can supply the palette.

## 3. Goals, non-goals, guarantees

**Goals**
1. One wrapper gives the app you already have a working dark theme.
2. Small input, rich output: you give 1–6 colors and get 48 coherent tokens plus a complete `ThemeData` for both modes.
3. Fits any architecture: a plain `ChangeNotifier`, pure functions, or your own state. No codegen.
4. Any toggle UX: a headless builder plus ready-made switch, icon, segmented, radio and menu widgets.
5. Fast feedback: hot reload updates both modes, and changes made at runtime animate.
6. Accessible by default: derived colors meet WCAG contrast, and your own colors get reported if they don't.
7. Incremental: hardcoded colors keep working while you migrate screen by screen, and tooling finds what's left.

**Non-goals**
- Not a design system or widget library. It handles colors only; typography, shapes and spacing stay yours.
- Not a rival to flex_color_scheme's hundreds of style options.
- No runtime tricks on hardcoded colors (no global color filters or inversion).
- Native splash screens, WebView content and map styles are out of scope (the docs have recipes for them).

**Guarantees, so it doesn't mess up your app** (each one is a test)
1. **Your light theme stays yours.** With a base theme, `t.light` is your `ThemeData` plus one `ThemeExtension`. Nothing else changes.
2. **You can always go back.** `setMode(ThemeMode.light)` shows exactly your original theme. `reset()` does the same and also clears the saved choice. `ThemeFlow(enabled: false)` turns dark mode off entirely, for example behind a remote flag.
3. **No hidden side effects.** The only global effect is one root `AnnotatedRegion` for the system bars, and one flag turns it off. The first frame is only deferred if you ask for it.
4. **Few dependencies.** Only `flutter` and `shared_preferences`, with wide version ranges. The audit tool is a separate package, so `analyzer` never enters your app's dependency graph, where it would clash with the versions pinned by freezed, json_serializable and build_runner.
5. **No singletons.** Several controllers can run side by side (an app theme and a reader theme, or tests).
6. **Color problems never crash the app.** Contrast problems are debug warnings, never exceptions in release.

## 4. A 60-second tour

**New app**
```dart
final theme = ThemeFlowController();          // remembers the user's choice

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await theme.load();                         // read it before the first frame: no flash
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeFlow(
      controller: theme,
      light: const ThemePalette(primary: Color(0xFF3D5AFE)),   // dark is derived
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

**Existing app** (keep your theme and get dark for free)
```dart
ThemeFlow(
  controller: theme,
  base: AppTheme.light,          // your current ThemeData, untouched in light mode
  builder: (context, t) => MaterialApp.router(
    theme: t.light,
    darkTheme: t.dark,
    themeMode: t.mode,
    routerConfig: router,
  ),
);
```
You don't need a palette here because it's read from your theme. You can add `light:` or `dark:` later to fine-tune. Widgets that already use `Theme.of(context).colorScheme` switch modes with no changes.

**Toggle from anywhere**
```dart
const ThemeModeSwitch();                    // adaptive switch: on = dark
const ThemeModeSegmented();                 // System | Light | Dark
ThemeModeBuilder(                           // your own design-system control
  builder: (context, s) => MyToggle(value: s.isDark, onChanged: (_) => s.toggle()),
);
context.themeFlow.setMode(ThemeMode.dark);  // from code: a cubit, a provider, a button
```

**Read colors**
```dart
Container(color: context.palette.surface);
Text('Due tomorrow', style: TextStyle(color: context.palette.textSecondary));
Icon(Icons.star, color: AppColors.gold.of(context));    // your own token
```

## 5. Core concepts

### 5.1 Data flow

```
ThemePalette            what you write: 1–6 colors, every token optional
   │  resolve           auto-dark (or auto-light) rules, then a contrast pass
   ▼
ResolvedPalette         every token has a concrete value; it's a ThemeExtension (lerps, works in dialogs)
   │  generate  or  recolor(base)
   ▼
ThemeData light / dark  →  MaterialApp(theme:, darkTheme:, themeMode:)
```

- **Config lives in the widget, state lives in the controller.** Palettes and the base theme are `ThemeFlow` parameters, so hot reload shows a palette edit in both modes straight away. A palette created in `main()` would never hot-reload, because `main()` doesn't run again. The controller only holds the user's choices: mode, variant and runtime overrides.
- **Tokens live inside `ThemeData`** as a `ThemeExtension`. Flutter then handles the hard parts for us: choosing between `theme` and `darkTheme`, following the system setting, animating the switch (`ThemeData.lerp` lerps extensions), and updating open dialogs and sheets.

### 5.2 Tokens

Ways to create a palette:
```dart
const ThemePalette(primary: Color(0xFF3D5AFE));                     // just a brand color
const ThemePalette(primary: brand, background: Color(0xFFF7F7F5), text: Color(0xFF1B1B1F));
const ThemePalette.seed(Color(0xFF3D5AFE));                         // Material 3 tonal palette from one color
ThemePalette.fromTheme(AppTheme.light);                             // read from your ThemeData
ThemePalette.fromColorScheme(scheme);                               // e.g. from dynamic_color
```

The light and dark slots work the same way. If you set a value, it wins. Anything you didn't set is derived from the other slot, or failing that, from the defaults. Most apps set `primary` and maybe 2–5 more.

| Group | Tokens | Used for | Maps to (Material 3) |
|---|---|---|---|
| Brand | `primary` `onPrimary` `primaryContainer` `onPrimaryContainer` | buttons, selection, focus; tinted chips and badges | same names in `ColorScheme` |
| | `secondary` … `onSecondaryContainer` (4) | a quieter companion to primary (defaults to primary's hue at lower chroma) | same |
| | `tertiary` … `onTertiaryContainer` (4) | a contrasting accent (defaults to primary's hue + 60°) | same |
| Surfaces | `background` | scaffold | `surface`, `scaffoldBackgroundColor` |
| | `surface` | cards, sheets, list rows | `surfaceContainerLow` |
| | `surfaceElevated` | dialogs, menus, popovers | `surfaceContainerHigh` |
| | `fill` | filled inputs, search bars, chips | `surfaceContainerHighest` |
| | `inverseSurface` `onInverseSurface` | snackbars, tooltips | same |
| Content | `text` | body text, primary icons | `onSurface` |
| | `textSecondary` | subtitles, secondary icons | `onSurfaceVariant` |
| | `textTertiary` | hints, timestamps, placeholders | input hint style |
| | `textDisabled` | disabled labels | `disabledColor` |
| | `link` | inline links | (none) |
| Lines | `border` | input borders, outlined buttons, checkboxes | `outline` |
| | `divider` | dividers, hairlines | `outlineVariant` |
| | `focus` | focus rings | `focusColor` |
| Status | `error` `success` `warning` `info`, each with `on…`, `…Container` and `on…Container` (16 total) | messages, badges, banners | the `error` roles; the other three are new |
| Effects | `overlay` | pressed/hover tint for custom widgets | (none: Material keeps its own state layers) |
| | `selection` | text selection highlight | `textSelectionTheme` |
| | `skeleton` `skeletonHighlight` | loading placeholders, shimmer | (none) |
| | `scrim` `shadow` | modal barriers, shadows | same |

That's 48 tokens. Every `ColorScheme` role is filled in too (including `surfaceContainer*`, `*Fixed`, `inversePrimary` and `surfaceDim`/`surfaceBright`), so every Material widget's defaults match the palette. The tokens are the set apps actually reach for, plus the colors Material doesn't define.

### 5.3 Your own tokens: `ColorToken`

```dart
abstract final class AppColors {
  static const gold = ColorToken(0xFFC9A227, id: 'gold');            // dark is derived
  static const page = ColorToken(0xFFF4ECD8, id: 'page',
      role: TokenRole.surface, dark: Color(0xFF1E1A14));            // dark is given
}

Icon(Icons.star, color: AppColors.gold.of(context));
```

- There's no codegen. Tokens are fully typed and autocomplete just like your existing `AppColors`.
- `ColorToken` **extends `Color`**, the same approach Flutter uses for `ColorSwatch` and `WidgetStateColor`. Its own value is the light color, so existing code that uses `AppColors.gold` as a plain `Color` keeps compiling and looks exactly as it did. You migrate one call site at a time by adding `.of(context)`, and the audit tool lists the call sites still missing it.
- `.of(context)` returns the value for the current mode, rebuilds when the mode toggles, and animates with the switch.
- The dark value is `dark:` if you give one. Otherwise it's derived from `role`, which defaults to `TokenRole.accent`.
- Equality is by `id`. Flutter's `Color.==` only compares runtime type and value, which can't tell two tokens apart. The `id` is also the key runtime overrides are saved under.

### 5.4 Roles

A role tells the derivation what a color is *for*, so dark mode never just inverts it. Custom tokens use roles, and so does the theme recolorer, which knows the role of every `ThemeData` field it walks.

| Role | Meaning | In dark mode |
|---|---|---|
| `surface` | something content sits on | dark, getting slightly lighter as elevation rises |
| `content` | text or icons on a surface | light, with contrast enforced against its surface |
| `outline` | borders, dividers | mid-dark, at 3:1 for interactive edges |
| `accent` | a saturated brand or status color used as a fill or as text | lighter and slightly calmer, at 3:1 on the background |
| `container` | a soft tinted background | a dark tint of the same hue |
| `onColor` | content on an accent or container | recomputed against whatever it sits on |
| `fixed` | never changes (logos, photo overlays) | unchanged |

## 6. Auto-dark: how colors are derived

**Color model: OKLCH** (perceptual lightness, chroma and hue).
- Not HSL. HSL lightness isn't perceptual (yellow and blue at "50%" look nothing alike), so lightness rules give uneven results.
- Not Material's HCT. HCT needs `material_color_utilities`, which Flutter pins to an exact version (0.13.0 in Flutter 3.44.4), and packages that depend on it break whenever Flutter bumps the pin. OKLCH is about 100 lines of math with no dependency.
- `ThemePalette.seed()` still uses Flutter's own `ColorScheme.fromSeed`, which is SDK API. It defaults to `DynamicSchemeVariant.fidelity` so the brand color stays recognisable.

**For each token, in the target brightness:**
1. If you gave a value, it's used unchanged.
2. Otherwise, take the token's value from the other brightness and re-tone it by role. The hue stays the same and lightness moves to the role's target. Chroma is scaled, so surfaces keep a hint of tint and accents calm down a little. Out-of-gamut results are brought back into sRGB by reducing chroma, never by shifting hue.
3. **Contrast pass.** For each pair in the table below, if a *derived* foreground fails, move its lightness away from its background until it passes. A binary search finds the smallest change. If the target can't be reached, use the best extreme and record a warning. Colors you set yourself are never changed, only reported.

**Starting lightness (OKLCH L, 0–100).** These get tuned during v0.1 against golden screenshots.

| Token | Light | Dark |
|---|---|---|
| background | 98 | 18 (about #121212) |
| surface | 100 | 22 |
| surfaceElevated | 100 | 26 |
| fill | 95 | 28 |
| text | 20 | 93 |
| textSecondary | 45 | 78 |
| textTertiary | 55 | 66 |
| border / divider | 62 / 91 | 55 / 30 |
| accents (primary, status, link, focus) | yours, or the defaults | 80 |
| …Container / on…Container | 94 / 30 | 32 / 92 |
| skeleton / skeletonHighlight | 93 / 97 | 26 / 31 |

**Contrast minimums (WCAG 2.2 ratios)**

| Foreground | Against | Minimum |
|---|---|---|
| text, textSecondary, link | background, surface, surfaceElevated, fill | 4.5:1 |
| on*X* | *X* | 4.5:1 |
| on*X*Container | *X*Container | 4.5:1 |
| onInverseSurface | inverseSurface | 4.5:1 |
| textTertiary | background, surface | 3:1 (non-essential text only) |
| border, primary, status colors | background, surface | 3:1 (UI components, WCAG 1.4.11) |
| divider, textDisabled | (none) | exempt |

The defaults land well above these minimums: default body text is about 15:1 in both modes. Contrast checking sits behind a `ContrastModel` interface. That way APCA, which comes from the WCAG 3 drafts and handles dark UIs better, can be added later without changing the API.

**`DarkStyle` options**
- `surfaces`: `tinted` (default; a hint of the brand hue, like Material 3), `neutral` (pure greys) or `black` (AMOLED: the background is 0 and surfaces run 12–20).
- `accentLightness`: defaults to 80.

*Brand-exact fills in dark mode* means keeping your exact brand color on filled buttons while text accents stay readable. That needs tuning per component, so it's planned for v0.3. Until then, `dark: ThemePalette(primary: brandColor)` keeps the color exact, and the contrast report shows where it's hard to read.

## 7. Building ThemeData

### 7.1 Generate mode (no base theme)
This builds a Material 3 `ThemeData` with a complete `ColorScheme` from the tokens. It also sets the component themes whose Material 3 defaults don't match the tokens:
- cards, dialogs, menus and popups
- inputs (fill, border, focus, hint)
- dividers, bottom sheets, snackbars and tooltips
- text selection
- the app bar, including its system overlay style
- the navigation bar, rail and drawer
- chips, list tiles and progress indicators
- ink colors and `cupertinoOverrideTheme`

Fonts and shapes are Flutter's defaults unless you pass a `base`.

### 7.2 Recolor mode (you already have a theme)
One function does all the "keep your theme" work:

```dart
ThemeData recolor(ThemeData theme, {required ResolvedPalette from, required ResolvedPalette to});
```

It walks every color in the theme and keeps everything else as it is: fonts, shapes, paddings, elevations and densities.
1. **Token match.** A color that matches a token in `from` becomes the same token in `to`. The match is alpha-aware, so `primary` at 12% stays at 12%. Each field also knows its natural token (a dialog background is `surfaceElevated`). That settles ties when several tokens share a value, as with white, which is often the background, the surface and `onPrimary` at once.
2. **Role re-tone.** A color that matches no token is re-toned by the role of the field it sits in: a background field is a `surface`, a foreground field is `content`, a border is an `outline`. Shadows and barriers keep their meaning and map to `shadow` or `scrim`, never to a text color. When the brightness doesn't change, colors with no matching token are left alone.
3. **Pair check.** Some foregrounds sit on a known background in the same component: button foreground and background, chip label and background, snackbar content and background, tooltip text and decoration, list tile text and tile color. These foregrounds are checked against the recolored background and fixed if needed.

The same function covers three jobs:

| Job | How |
|---|---|
| Dark mode from your light theme | `recolor(base, from: inferred(base), to: darkPalette)` |
| Your theme with a new palette (rebrand, white-label, runtime accent) | `recolor(base, from: inferred(base), to: newPalette)` |
| Light mode when you didn't give a palette | not called at all: `base` plus the extension, untouched (guarantee 1) |

If your app is dark-first, pass your dark theme as `base` and themeflow derives the light one.

`ThemePalette.fromTheme(base)` infers the palette from your theme. The exact rules will be in the dartdoc; the main ones are:
- `primary` from `colorScheme.primary`
- `background` from `scaffoldBackgroundColor`
- `surface` from `cardTheme.color`, else `surfaceContainerLow`
- `text` from `textTheme.bodyLarge.color`, else `onSurface`
- `border` from the input border, else `outline`
- `divider` from `dividerTheme.color`, else `outlineVariant`

**Coverage (Flutter 3.44)**
- the 18 direct color fields of `ThemeData` and every `ColorScheme` role
- `textTheme` and `primaryTextTheme`, `iconTheme` and `primaryIconTheme`, and `cupertinoOverrideTheme`
- all 47 component themes that carry colors: appBar, badge, banner, bottomAppBar, bottomNavigationBar, bottomSheet, button, card, carouselView, checkbox, chip, dataTable, datePicker, dialog, divider, drawer, dropdownMenu, elevatedButton, expansionTile, filledButton, floatingActionButton, iconButton, inputDecoration, listTile, menuBar, menuButton, menu, navigationBar, navigationDrawer, navigationRail, outlinedButton, popupMenu, progressIndicator, radio, scrollbar, searchBar, searchView, segmentedButton, slider, snackBar, switch, tabBar, textButton, textSelection, timePicker, toggleButtons, tooltip

Inside them, the walker handles:
- `Color` and `WidgetStateColor`
- `WidgetStateProperty<Color?>`, wrapped so state resolution still works
- `TextStyle` colors and shadows
- `BorderSide`, outlined shapes and `InputBorder`
- `BoxDecoration` and `ShapeDecoration` (color, border, gradient, shadows)
- `IconThemeData`
- `SystemUiOverlayStyle`, with icon brightness flipped for dark

Flutter 3.44 is partway through migrating `appBarTheme` and `inputDecorationTheme`. Both are typed `Object?` and accept either the old `AppBarTheme`/`InputDecorationTheme` classes or the new `…Data` classes. The walker handles both.

**Not handled (documented):**
- `Paint`-based text foregrounds
- custom `Decoration` subclasses
- other packages' `ThemeExtension`s

Your own extensions can take part by implementing `Recolorable`, which has one method: `recolor(ColorMapper map)`. Or you can pass dark instances through `darkExtensions:`.

### 7.3 Bring your own dark theme
`darkBase: AppTheme.dark` is used as it is, with the dark palette extension added. flex_color_scheme users can pass `base: FlexThemeData.light(...)` and `darkBase: FlexThemeData.dark(...)`, and themeflow adds the tokens, state and toggles.

### 7.4 Performance
- Themes are rebuilt only when config or state changes, and are cached.
- `ResolvedPalette` has value equality, so rebuilding `App` with the same palette doesn't restart MaterialApp's theme animation.
- Custom tokens resolve lazily and are cached per palette.
- Lerped palettes resolve on demand and short-circuit at t = 0 and t = 1, so interrupted animations never pile up.
- Targets: resolving a palette under 1 ms, and recoloring under 3 ms on a mid-range phone.

### 7.5 Pure functions
Everything `ThemeFlow` does is also available as plain functions, for apps that want to wire it up themselves or test it:
- `resolvePalettes(light:, dark:, style:)` returns the light and dark `ResolvedPalette`
- `generateTheme(palette)`
- `recolor(theme, from:, to:)`

## 8. State: `ThemeFlowController`

```dart
class ThemeFlowController extends ChangeNotifier {
  ThemeFlowController({
    ThemeFlowStorage? storage,        // default: shared_preferences; ThemeFlowStorage.none to opt out
    String storageKey = 'themeflow',  // separate keys for separate scopes (app, reader)
    ThemeMode initialMode = ThemeMode.system,
  });

  ThemeMode get mode;
  Brightness get brightness;          // what's on screen, including in system mode
  bool get isDark;

  Future<void> load();                // read the saved choice (call before runApp)
  void setMode(ThemeMode mode);
  void toggle();                      // light <-> dark; in system mode, flips what's on screen
  void cycle();                       // system -> light -> dark -> system
  Future<void> reset();               // back to your config, and clears the saved choice

  // v0.3
  void selectVariant(String id);      // e.g. 'sepia', 'black'
  void setAccent(Color? color);       // brand color picked by the user; null goes back to yours
  void setOverride(ColorToken token, Color? color);
}
```

**Storage** is a two-method interface, so Hive, secure storage or HydratedBloc work too:
```dart
abstract interface class ThemeFlowStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);    // null deletes
}
```
The package ships three:
- `SharedPreferencesThemeStorage`: the default, built on `SharedPreferencesAsync`
- `MemoryThemeStorage`: for tests
- `ThemeFlowStorage.none`: no persistence

The saved value is one small versioned JSON string, for example `{"v":1,"mode":"dark","variant":null,"accent":"#3D5AFE","overrides":{"gold":"#D4AF37"}}`. If the data is missing or corrupt, the defaults are used and nothing throws.

**No flash at launch.** Call `await controller.load()` before `runApp`. If you can't change `main()`, use `ThemeFlow(deferFirstFrame: true)`. It holds the first frame until the choice is read, for at most 500 ms, so the native splash stays up meanwhile. It uses Flutter's `deferFirstFrame`/`allowFirstFrame`.

**Your state, our themes (controlled mode).** If you already keep the mode in a cubit, a provider or a GetX controller, you don't need our controller:
```dart
ThemeFlow(
  mode: state.themeMode,                 // from your state
  onModeChanged: cubit.setThemeMode,     // our toggles call this
  light: AppPalette.light,
  builder: (context, t) => MaterialApp(theme: t.light, darkTheme: t.dark, themeMode: t.mode),
);
```
There are three ways in; pick one:
- a controller
- controlled mode
- nothing at all (zero-config: `ThemeFlow` creates its own controller with default storage)

It works with any app widget that takes `theme`, `darkTheme` and `themeMode`: `MaterialApp`, `MaterialApp.router`, `GetMaterialApp` and so on. The docs include ten-line recipes for setState, Provider, Riverpod, BLoC/Cubit, GetX and get_it.

## 9. Widgets

### 9.1 `ThemeFlow`
```dart
ThemeFlow({
  ThemeFlowController? controller,                       // or the next two (controlled mode)
  ThemeMode? mode,
  ValueChanged<ThemeMode>? onModeChanged,
  ThemePalette? light,
  ThemePalette? dark,                                    // partial is fine: overrides on top of auto-dark
  ThemeData? base,
  ThemeData? darkBase,
  DarkStyle darkStyle = const DarkStyle(),
  bool enabled = true,                                   // false: always your light theme, and toggles hide
  bool systemBars = true,
  bool deferFirstFrame = false,
  required Widget Function(BuildContext context, ThemeFlowThemes t) builder,
});
```
`t` carries:
- `light`, `dark`, `mode`, `brightness` and `palette`
- `cupertino`, a `CupertinoThemeData` for `CupertinoApp` (which has no `darkTheme`)
- from v0.3, `highContrastLight` and `highContrastDark`

### 9.2 Reading colors
| API | Returns |
|---|---|
| `context.palette` | the nearest `ResolvedPalette`, or a clear error if there isn't one ("did you pass t.light / t.dark to MaterialApp?") |
| `token.of(context)` | your `ColorToken`'s current value |
| `context.isDark` | the brightness actually on screen (correct in system mode and inside `ForceBrightness`) |
| `context.pick(light: a, dark: b)` | a reactive one-off choice of anything (colors, images, Lottie paths). It replaces `isDark ? a : b` |
| `context.themeFlow` | `mode`, `setMode`, `toggle` and `cycle` (works in controlled mode too) |
| `ThemeFlow.themesOf(context)` | the light and dark `ThemeData` and both palettes, anywhere below |

If another package in your app also defines `context.palette` or `context.isDark`, use `ResolvedPalette.of(context)`, or `hide` our extension.

### 9.3 Toggles
All the toggles are thin wrappers over `ThemeModeBuilder`. Their names all start with `ThemeMode`, so autocomplete lists them together. Each one has semantics labels, an `adaptive` option (Cupertino on iOS and macOS) and a `labels:` parameter for localisation.

| Widget | UX |
|---|---|
| `ThemeModeBuilder` | headless: gives you `mode`, `isDark`, `setMode`, `toggle` and `cycle` to wrap your own design-system control |
| `ThemeModeSwitch` | a switch; on means dark |
| `ThemeModeSwitchTile` | a settings row with title and subtitle |
| `ThemeModeButton` | an icon button with an animated sun/moon (toggle), or sun/moon/auto (cycle) |
| `ThemeModeSegmented` | a System / Light / Dark segmented button |
| `ThemeModeRadios` | a radio list for settings screens (built on Flutter's `RadioGroup`) |
| `ThemeModeMenu` | a popup menu |
| `ThemeVariantPicker` (v0.3) | swatches for Light, Sepia, Dark, Black, … |
| `AccentPicker` (v0.3) | brand color swatches that call `setAccent` |

In system mode, a switch shows what's on screen (on if the system is dark). Flipping it picks an explicit mode. The segmented button, radios and menu show System as an option of its own.

### 9.4 Escape hatches
- **`ForceBrightness.dark(child:)` and `.light`** render a subtree in the other scheme whatever the mode, for a video player, photo viewer or onboarding hero.
- **`PaletteOverride(colors: {AppColors.gold: Colors.amber}, child:)`** re-tints a subtree. For built-in tokens, use `update: (p) => p.copyWith(...)`. It's built on `Theme`, so Material widgets inside it follow along.
- **`ThemedImage(light:, dark:)`** swaps images. **`ThemedImage.dimmed(image)`** gently dims photos and white-background illustrations in dark mode.
- **SVGs:** pass `ColorFilter.mode(context.palette.text, BlendMode.srcIn)` to `SvgPicture`. themeflow doesn't depend on flutter_svg.
- **Scoped themes (v0.3)** are for an area with its own theme choice, like a reader with Light / Sepia / Night that's separate from the app's mode. You use a second controller with its own `storageKey`, and wrap the area in `ThemeFlow.scoped(...)`.

### 9.5 System bars
Generated and recolored themes set `appBarTheme.systemOverlayStyle` for each brightness. In recolor mode, your light style is kept and its icon brightness is flipped for dark.

With `systemBars: true`, `ThemeFlow` adds one root `AnnotatedRegion<SystemUiOverlayStyle>`. That way, screens without an AppBar still get readable status-bar icons and a matching Android navigation bar. App bars still take over on their own screens. Turn it off if you manage `SystemChrome` yourself.

## 10. Migration tool: `themeflow_audit` (v0.2)

```bash
dart pub global activate themeflow_audit
themeflow_audit                            # scans lib/ and prints a report
themeflow_audit --format markdown > dark-mode-report.md
themeflow_audit --fail-under 90            # CI gate on the readiness score
themeflow_audit --fix --dry-run            # v1.0: rewrites exact matches, shows the diff first
```

It's built on `package:analyzer`, so it reads real syntax trees and types rather than using regex. Installing it with global activation keeps it out of your app entirely.

| Finds | Example | Suggests |
|---|---|---|
| raw colors in widget code | `Color(0xFF1C1C1C)`, `Colors.white`, `Color.fromARGB(…)` | the matching or nearest token, e.g. `context.palette.text` |
| color constants used directly | `AppColors.grey600` (a const `Color`) | turning the class into `ColorToken`s |
| tokens used without `.of(context)` | `color: AppColors.gold` | `AppColors.gold.of(context)` |
| brightness checks | `isDark ? a : b`, `brightness == Brightness.dark` | `context.pick` or a token |
| platform brightness reads | `MediaQuery.platformBrightnessOf(context)` | `context.isDark`, because this ignores the user's choice |
| manual system bar styling | `SystemChrome.setSystemUIOverlayStyle(…)` | letting themeflow handle it, or checking both modes |

It skips:
- `Colors.transparent`
- theme definition files (configurable)
- tests
- generated files (`*.g.dart`, `*.freezed.dart`)
- lines marked `// themeflow: ignore`

Suggestions use your palette when it's declared as a `const`, because the analyzer can evaluate constants. Otherwise they come from an optional `themeflow_audit.yaml`.

The report lists findings per file with line numbers, gives totals and a **readiness score** (color uses that go through tokens ÷ all color uses), and comes as console text, JSON or Markdown (for PR comments).

## 11. Developer tools

- **Contrast report.** `palette.contrastReport()` lists every pair with its ratio, the minimum and pass/fail. In debug builds, failures print once per palette with a suggested fix, e.g. "textSecondary on surface is 3.2:1, needs 4.5:1; nearest passing color #6B6B6B". Put it in a unit test to keep it green:
  ```dart
  test('palette stays readable', () {
    final p = resolvePalettes(light: AppPalette.light);
    expect(p.light.contrastReport().failures, isEmpty);
    expect(p.dark.contrastReport().failures, isEmpty);
  });
  ```
- **Inspector (v0.3).** It's debug-only and stripped from release builds. A floating button opens a panel over your real screens with:
  - a mode switch
  - every token, with its swatch and a contrast badge
  - tap-to-edit (picker or hex), updating live
  - "Copy as Dart" and "Copy as JSON"
- **JSON (v0.3).** `ThemePalette.fromJson` and `toJson` (hex strings) support server-driven branding and white-label apps.

## 12. Package layout

v0.1 is a single package under `packages/`. The pub workspace root (Dart ≥ 3.6, so melos isn't needed) arrives with `themeflow_audit` in v0.2, once publishing a workspace member has been checked with pana.

```
themeflow/
  packages/
    themeflow/                      runtime package
      lib/themeflow.dart            the one public import
      lib/src/color/                oklch, gamut mapping, contrast
      lib/src/palette/              ThemePalette, ResolvedPalette, ColorToken, roles, derivation
      lib/src/theme/                generate, recolor (the walker), color scheme, system bars, cupertino
      lib/src/state/                controller, storage, saved-state format
      lib/src/widgets/              ThemeFlow, context extensions, toggles, overrides, ThemedImage
      tool/                         generators for the token lists and the recolor test fixture
      doc/                          screenshots for pub.dev
      example/                      an "existing app" given dark mode by one wrapper
      test/
    themeflow_audit/                v0.2: pure Dart CLI
  docs/DESIGN.md (this file)
  .github/workflows/                ci.yaml, publish.yaml
```

**Dependencies**
- `themeflow`: `flutter` and `shared_preferences: '>=2.3.0 <3.0.0'`, nothing else. 2.3.0 is the first version with `SharedPreferencesAsync`; 2.5.5 is current.
- `themeflow_audit`: `analyzer`, `args`, `path` and `yaml`.

**SDK floor:** the aim is the last four stable Flutter releases. v0.1 requires Flutter 3.44 (Dart 3.12), the version it was built and tested on. The CI matrix already runs the floor, the latest stable and beta, and the floor drops once older releases pass there.

## 13. Quality bar

**Tests**
- **Color math:** OKLCH round trips, gamut mapping that keeps hue, and WCAG ratios checked against reference values (black on white is 21:1).
- **Property test:** for 1,000 random brand colors × 3 dark styles, every derived pair meets its minimum in both modes.
- **Recolor exhaustiveness:** build a "maximal" `ThemeData` with a unique sentinel color in every color field of every component theme, then recolor it. Walk the diagnostics tree and fail if any sentinel survives. This runs on stable and beta, so a new Flutter color field shows up in CI before it shows up in someone's app.
- **Identity:** in recolor mode, `t.light` equals `base` apart from the extension.
- **Widgets:**
  - every toggle transition
  - system mode while the platform brightness changes
  - a persistence round trip, and corrupt saved data
  - controlled mode
  - a dialog and a bottom sheet open while the mode changes (they must update live)
  - `ForceBrightness` and `PaletteOverride`
- **Goldens:** a kitchen-sink screen in light, dark, black-surface dark and a recolored existing theme. They use Flutter's test font and were recorded on macOS, so CI runs them on macOS only.
- **Audit:** fixture projects with expected reports.

**CI (GitHub Actions)**
- format and analyze (infos are fatal)
- tests with coverage (≥ 90% on color, palette and theme) and goldens
- pana, targeting full pub points (160 today)
- `dart pub publish --dry-run`
- matrix: the SDK floor, stable and beta

**Release:** pushing a tag like `themeflow-v0.1.0` publishes from GitHub Actions through pub.dev's automated publishing (OIDC, so no tokens are stored). This only happens once you say go.

**Docs**
- A README that leads with the existing-app path and a GIF of a real app switching modes.
- `docs/migration.md`, the afternoon plan: wrap, add a toggle, run the audit, replace colors, fix images, add the contrast test.
- `docs/recipes.md`: state management, flex_color_scheme, dynamic_color, SVG, native splash, WebView and maps.
- dartdoc on 100% of the public API.
- pubspec `topics: [theme, dark-mode, colors, material-design, accessibility]`, plus screenshots.

## 14. Milestones

**v0.1 Core (first publish)**
- Scope:
  - the color engine
  - tokens and `ColorToken`
  - auto-dark and auto-light with the contrast pass
  - generate mode, and recolor mode with full coverage
  - the controller, storage, no-flash load and controlled mode
  - the context API
  - toggles: builder, switch, tile, button, segmented, radios, menu
  - `ForceBrightness`, `PaletteOverride` and `ThemedImage`
  - system bars and the contrast report
  - the example app, tests and CI
- Done when the example's light-only demo app gets a correct dark mode from one wrapper, all six guarantees have tests, and the package has full pub points.

**v0.2 Find what's left**
- Scope: the `themeflow_audit` report (console, JSON and Markdown output, readiness score, CI gate, nearest-token suggestions, ignore comments) and `docs/migration.md`.
- Done when the audit runs clean on its own example and gives useful output on 3 open-source apps.

**v0.3 Make it yours**
- Scope:
  - variants (Sepia, Black, custom) and `ThemeVariantPicker`
  - scoped themes
  - runtime accent and token overrides (saved), and `AccentPicker`
  - the Inspector
  - high-contrast themes
  - JSON palettes
  - brand-exact fills
  - first-class `CupertinoApp` and `WidgetsApp` support
- Done when a reader-style app can offer Light / Sepia / Night separately from the app's mode.

**v1.0 Stable**
- Scope:
  - audit `--fix`
  - an analyzer plugin with lints and quick fixes
  - an optional circular-reveal transition
  - an API review and freeze (semver from here on: deprecate before removing)
- Done when a real app has been migrated end to end with the tools, and no breaking changes are planned.

This differs from the plan in chat: auto-dark and recolor have moved into v0.1. They're the reason to choose themeflow over adaptive_theme, so the first release has to include them.

## 15. Risks

| Risk | Mitigation |
|---|---|
| Flutter theming keeps changing: component themes get renamed and new color fields appear (`appBarTheme` and `inputDecorationTheme` are mid-migration in 3.44) | the exhaustiveness test on stable and beta; the walker kept in one place; a clear SDK floor |
| Flutter moves Material and Cupertino out of the core framework (decoupling is planned) | use only public `package:flutter/material.dart` APIs, and follow the move when it lands |
| Auto-dark can't read the designer's mind | your values always win; per-token `dark:`; the contrast report; the Inspector |
| Developers forget `.of(context)` on a `ColorToken`, so the light value shows in dark mode | the audit lists them; a v1.0 lint with a quick fix |
| A new `ThemeData` on each build restarts the theme animation | value-equal palettes and cached themes |
| Third-party widgets with hardcoded colors | `PaletteOverride` and `ForceBrightness`; documented |
| Someone takes the name first | it's free today. Publish a real 0.1 rather than a placeholder, since pub.dev discourages name squatting |

## 16. Decisions (taken 2026-10-01)

All recommendations were taken:

1. **Default dark surfaces:** tinted with the brand hue, like Material 3.
2. **Persistence:** `shared_preferences` built in.
3. **SDK floor:** the last four stable Flutter releases, once CI verifies them (3.44 for now, see §12).
4. **License:** MIT.
5. **Publisher:** a verified publisher on a domain you own. Set up at publish time.
6. **Repo:** public on your GitHub. Not created yet: it's a public, outward-facing step, so it waits for your go.
7. **Naming:** `context.palette`.

## 17. What changed while building v0.1

- The repo is a single package for now. The workspace root comes with the audit tool (§12).
- The SDK floor is Flutter 3.44 until CI checks older releases (§12).
- `overlay` isn't written into Material's ink colors in generate mode. Material 3 keeps its own state layers; recolor still carries any ink colors your base theme sets.
- `ThemeFlow.themesOf(context)` was added. `ForceBrightness` needs it, and it's handy for previews.
- The token lists in three files are generated from one spec (`tool/palette_tokens.py`), and the recolor test fixture from the installed Flutter SDK (`tool/generate_busy_theme.py`).
- `PaletteOverride(colors:)` can't be a `const` map, because a `ColorToken` has its own equality. The examples don't use `const` there.
- The legacy `ButtonThemeData` keeps its colors private, so recolor carries the ones `ThemeData` fills in (disabled, focus, hover, highlight, splash) rather than reading them.
- The deprecated `ColorScheme` roles (`background`, `onBackground`, `surfaceVariant`) are carried over too, because older packages still read them.
