# Hardwire — instructions for Claude Code

Hardwire is a Godot 4 (GDScript) mobile puzzle game. **`docs/SPEC.md` is the source of truth** — read the relevant sections before every task.

## How we work

- Build one milestone per session, in order (SPEC: "Milestones and acceptance criteria"). Do not start the next milestone until the current one meets its "Done when" criteria.
- At the end of a milestone: run the tests, run the game once headless to check for script errors, and summarize what to play-test.
- If the spec is ambiguous or a number seems wrong, ask instead of guessing. Never change `docs/SPEC.md` silently; propose the change.

## Conventions

- Static typing everywhere (`var x: int`, typed parameters and return types).
- Every tuning number lives in `data/balance.json` and is read through the `Balance` autoload. No balance literals in game code.
- `logic/` is pure GDScript (`RefCounted`, no nodes, no autoload access except `Balance`) and fully unit-tested.
- Puzzles get a `SlotDef` and an attempt seed and emit `solved(result)` / `failed()`. They never touch `GameState` directly and never own the screen (needed for the later Benchmark slot).
- Pointer input is touch only; the mouse is emulated (`emulate_touch_from_mouse`). Gamepad and keyboard go through InputMap actions (`ui_*`, `commit`), never raw keys or buttons.
- Rhythm timing: `Time.get_ticks_usec()` inside `_input`, never `_process`.
- Build UI mostly in code on top of minimal `.tscn` files, so changes don't need the Godot editor.
- Autoload scripts have no `class_name` (it would clash with the singleton name).
- Indentation: tabs in `.gd` files.

## Commands

```bash
# Run the game (landscape 1280x800 window, like a Steam Deck; resize it taller than wide for the phone layout)
godot --path .

# Re-import resources / check for script errors without a window
godot --headless --path . --import

# Run all unit tests with the CI checks (GUT is vendored in addons/gut)
tools/run_tests.sh
```

## Gotchas

- `data/balance.json`, `LICENSE` and `fonts/JetBrainsMono-OFL.txt` are not Godot resources. Every export preset must include them via "Filters to export non-resource files".
- `.godot/` is a cache; never commit or edit it.
- Controls built in code: use `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`, not `set_anchors_preset`. On a node already in the tree the latter keeps the old (often zero) rect.
- Puzzles run on `_process` with scaled delta, never `await`, so an attempt can be aborted or freed at any time. Tests drive them by calling `_process(FRAME)` directly.
- GUT silently skips a test script with a parse error and still reports "All tests passed". Check the output for `SCRIPT ERROR` or "Ignoring script", and check that the script count is right.
- Exports: `godot --headless --path . --export-release "Web" build/web/index.html` (needs export templates 4.7.2). Android also needs the Android SDK and JDK 17 configured in the editor settings.
- Exit prints "1 ObjectDB instance was leaked" (`AudioStreamGeneratorPlayback` from `Synth`). This is engine teardown at quit and harmless.
- Do not add ads, analytics or tracking SDKs (SPEC: Decisions — no monetization).
