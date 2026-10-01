# themeflow

Dark mode for an existing Flutter app in an afternoon, and a clean theming
setup for new ones.

| Package | What it is |
|---|---|
| [`themeflow`](packages/themeflow) | The runtime package: keeps your light theme, derives a contrast-checked dark one, tokens, saving, toggles |
| `themeflow_audit` (0.2, planned) | A command that lists the hardcoded colors left in your code |

- Docs and usage: [packages/themeflow/README.md](packages/themeflow/README.md)
- Design: [docs/DESIGN.md](docs/DESIGN.md)
- Example app: [packages/themeflow/example](packages/themeflow/example)

## Working on it

```bash
cd packages/themeflow
flutter test --exclude-tags golden   # unit and widget tests
flutter test --tags golden           # golden images (recorded on macOS)
flutter analyze --fatal-infos
```

Two generators keep long lists in sync:

- `python3 tool/generate_palette.py`: the 48 token lists, from
  `tool/palette_tokens.py`.
- `python3 tool/generate_busy_theme.py`: the recolor test fixture, from the
  installed Flutter SDK. Rerun it after a Flutter upgrade; the coverage test
  tells you when that's needed.

## License

MIT
