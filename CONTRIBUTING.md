# Contributing to Hardwire

Thanks for helping! Bug reports, balance feedback from play-testing, and pull requests are all welcome.

## Before you start

- Read [`docs/SPEC.md`](docs/SPEC.md). It is the source of truth for how the game works. If your change alters behaviour or a number, update the spec in the same pull request and add a new entry to [`docs/DECISIONS.md`](docs/DECISIONS.md) saying why (CI enforces this; old entries are never edited).
- For anything bigger than a bug fix, open an issue first so we can agree on the approach.
- Hardwire has no ads, analytics, tracking or purchases, and won't accept them.

## Setup

1. Install [Godot 4.7.2](https://godotengine.org/download) (standard build) and put `godot` on your PATH, plus Python 3.
2. Clone the repo and run `tools/setup.sh` (installs the pinned gdformat/gdlint into `.venv`).
3. Run the game with `godot --path .` and the quality gate with `tools/check.sh` (the same checks as CI).

## Conventions

- **Static typing everywhere** (`var x: int`, typed parameters and return values). Tabs for indentation in `.gd` files (see `.editorconfig`).
- **No tuning numbers in code.** Every balance number lives in `data/balance.json` and is read through the `Balance` autoload. Colors, sizes and durations live in `theme/hardwire_theme.tres`.
- **`logic/` stays pure:** `RefCounted` classes with no nodes and no autoload access except `Balance`, all covered by unit tests.
- **Puzzles** receive a `SlotDef` and a seed, and emit `solved` / `failed`. They never touch `GameState` and never own the screen.
- **Input:** pointer input is touch only (the mouse is emulated). Gamepad and keyboard go through InputMap actions (`ui_*`, `commit`), never raw keys or buttons. Every screen must work with touch alone and with a controller alone. Rhythm timing uses `Time.get_ticks_usec()` inside `_input`.
- **Layouts:** one code path per screen for portrait and landscape (`Ui` helpers, `BoxContainer.vertical`, `GridContainer.columns`). `test_layout` checks every screen at phone, 16:9 and 16:10 sizes.
- **UI** is built mostly in code on top of minimal `.tscn` files, so changes don't need the Godot editor.
- Commit `.import` and `.uid` files; never commit `.godot/`.

More details and known pitfalls are in [`CLAUDE.md`](CLAUDE.md).

## Pull requests

- Keep each pull request focused on one change, with a clear description.
- Add or update tests for logic changes; `logic/X.gd` is tested in `tests/logic/test_x.gd`. `tools/check.sh` must pass: format, lint, drift checks (no tuning numbers in logic, no duplicated blocks, functions ≤ 40 lines, input only through InputMap actions), script errors and tests. Never weaken a test or a limit to get green.
- If you changed something players can see, describe how to play-test it.
- By contributing, you agree that your contribution is licensed under the [MIT License](LICENSE).

## Reporting bugs

Use the bug report template. Include your platform (desktop, web browser, Android device), the build or commit, steps to reproduce, and what you expected.
