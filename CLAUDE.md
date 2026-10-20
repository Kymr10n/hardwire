# Hardwire — working rules for Claude Code

Hardwire is a Godot 4.7 (GDScript) puzzle game for phones (Android, iOS), PC (Windows, Linux, macOS), Steam Deck and the web.
`docs/SPEC.md` is the source of truth. `docs/DECISIONS.md` says why. `docs/PROGRESS.md` says where we are.

**The goal is the smallest, clearest code that meets the spec — not the most code.** Deleting code is progress.

## Workflow

- Work through `/milestone M#`, one milestone per session, in order. Ad-hoc changes end with `/review`.
- Read the relevant spec sections and the code you touch before writing anything.
- Ask when the spec is ambiguous or seems wrong. Never guess, never silently deviate. Spec changes go through `/spec-change`.
- Tests first for anything in `logic/`. A bug fix starts with a failing test.
- Done means: `tools/check.sh` passes, `reviewer` and `spec-auditor` have no open must-fix items, `docs/PROGRESS.md` is updated, changes are committed.

## Principles

- **KISS.** Choose the simplest design that meets today's spec. No frameworks, managers, plugin systems, event buses, generic factories or configuration nobody asked for. Prefer plain functions and data.
- **YAGNI.** Build only what the current milestone needs. No hooks "for later"; the only planned extension point is the chainable puzzle interface (D-005).
- **DRY — one home for every fact:**
  - numbers → `data/balance.json` (read via `Balance`)
  - rules and formulas → `logic/` (pure, tested); `GameState` holds state and mutations only
  - behavior → `docs/SPEC.md`; decisions → `docs/DECISIONS.md`; status → `docs/PROGRESS.md`
  - input bindings → the InputMap in `project.godot`; last device and glyphs → `InputMode`
  - portrait/landscape → `Main` + `Ui.is_landscape()`; shared UI building blocks → `scenes/ui/Ui.gd`
  - colors, fonts, sizes, durations → the theme; drawing proportions → named `const`s in their file
  - Extract shared code when it appears the second time; don't build abstractions for one caller.
- **Use Godot, don't rebuild it:** Containers for layout, `Tween` for animation, `Timer`, signals, `InputMap`, focus navigation, `Theme`, `RandomNumberGenerator` with a seed.
- **Small units** (enforced): files ≤ 300 lines, functions ≤ 40 lines, ≤ 5 parameters, lines ≤ 100 characters, ≤ 12 public methods per class. Static types everywhere.
- Comments explain *why*, not *what*. No dead or commented-out code.

## Architecture rules (enforced by `tools/drift_check.py`)

- `logic/` is pure `RefCounted` code: no nodes, no `GameState`, no input. Every `logic/X.gd` with functions has `tests/logic/test_x.gd`.
- Puzzles take a `SlotDef` + seed, emit `solved(result)` / `failed()`, never touch `GameState` and never own the screen. Upgrade levels reach them through `SlotDef.assist`.
- No balance literals in `logic/` or `scenes/puzzles/` (except 0, 1, 2, -1, 0.5 and unit conversions). Mark a deliberate exception with `# drift:ok <reason>`.
- Gameplay reads InputMap actions only; only `autoload/InputMode.gd` may touch raw keys, buttons or device types. Pointer input is touch (the mouse is emulated).
- Rhythm timing: `Time.get_ticks_usec()` inside `_input`, never `_process`.
- `TODO(M#)` markers only for future milestones; `tools/check.sh` fails if a done milestone still has one.
- Changing `docs/SPEC.md` requires a new entry in `docs/DECISIONS.md` in the same change. Decisions are append-only.

## Platform rules

- Every interaction works with touch, mouse, keyboard and gamepad (see SPEC: Platforms and input).
- Every screen works in portrait 540 × 960 and landscape 1280 × 800 with one code path (`BoxContainer.vertical`, `GridContainer.columns`, `Ui.screen_root`).
- Minimum font 32 px and targets 120 px at the 1080 × 1920 reference size. Prompts show glyphs for the last-used device (`InputMode.prompt` / `glyph`).

## Tests

- Test behavior from the spec, with the spec's numbers as fixtures. Don't assert private details.
- Never weaken, skip or delete a test or a limit to get green. If a check is wrong, stop and ask.
- Tests that touch `GameState` or screens extend `tests/hardwire_test.gd` (snapshots state, redirects the save file). Use `in_viewport()` for layout sizes and `press_action()` / `tap_action()` for gamepad/keyboard input.
- Test files with more than 12 cases start with `# gdlint: disable=max-public-methods` (D-020).
- Scenes get smoke tests (instantiate, signal emitted); feel is checked by play-testing.

## Commands

```bash
tools/setup.sh                                   # once: gdtoolkit (.venv) and version checks; GUT is vendored
tools/check.sh                                   # the quality gate: format, lint, drift, script errors, tests
godot --path .                                   # run (1280x800, Steam Deck size)
godot --path . --resolution 540x960              # run in phone portrait
tools/export.sh Linux build/linux/hardwire.x86_64   # export a preset (needs export templates 4.7.2)
tools/deck.sh [--run]                            # export + copy to the Steam Deck over SSH ($DECK, tools/deck.local.env)
tools/steam_upload.sh [--preview]                # export + upload Linux/Windows via SteamPipe (tools/steam.local.env)
```

## Harness (runs automatically)

- Before an edit: `.godot/`, `addons/`, `.venv/` and existing decision entries are protected.
- After an edit: `.gd` files are auto-formatted and linted; JSON is validated; a spec edit without a decision is flagged.
- Before finishing a turn that changed project files: `tools/check.sh` must pass.
- CI runs `tools/check.sh`, the spec/decision rule and the Linux, Windows and web exports.

## Gotchas

- `data/balance.json`, `LICENSE`, `fonts/VT323-OFL.txt` and `fonts/DSEG-OFL.txt` are not Godot resources: every export preset must list them under "Filters to export non-resource files".
- `.godot/` is a cache; never commit or edit it. `build/` and `docs/` carry a `.gdignore` so Godot never imports exports or screenshots.
- Autoload scripts have no `class_name` (it would clash with the singleton name).
- Controls built in code: use `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`, not `set_anchors_preset`; on a node already in the tree the latter keeps the old (often zero) rect.
- Puzzles run on `_process` with scaled delta, never `await`, so an attempt can be aborted or freed at any time. Tests drive them by calling `_process(FRAME)`.
- Godot's built-in `ui_accept` / `ui_cancel` have no gamepad buttons; `project.godot` re-lists them with A / B. Overriding an action replaces its whole event list.
- GUT exits 0 when a test script fails to parse; `tools/check.sh` catches that from the output.
- In tests, input pushed in the same frame a screen opens can be dropped; `await wait_process_frames(2)` first.
- Exit prints "1 ObjectDB instance was leaked" (`AudioStreamGeneratorPlayback` from `Synth`). This is engine teardown at quit and harmless.
- Tool versions are pinned in `tools/versions.env`; don't upgrade them without `/spec-change`.
- No ads, analytics or tracking SDKs (D-006).
