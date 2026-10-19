# Tests

Unit tests use [GUT](https://github.com/bitwes/Gut) and live here as `test_*.gd` files extending `GutTest`.
GUT 9.7.1 is vendored in `addons/gut` (pinned in `tools/versions.env`). `tools/check.sh` runs the suite and fails if GUT skipped a script that doesn't parse.

Rules (see CLAUDE.md → Tests):

- `tests/logic/test_<name>.gd` mirrors `logic/<Name>.gd` one-to-one; the drift check fails if a logic file with functions has no test file.
- Test behavior described in `docs/SPEC.md`, using the spec's own numbers as fixtures (for example the Sample tiers table). Never assert private implementation details.
- A bug fix starts with a test that fails before the fix.

What is covered:

- **Logic** (`tests/logic/`): generators against the SPEC Sample tiers table, `RhythmJudge` edge cases, economy, progress rules and `SlotDef`. Gameplay through `GameState` (first solves, upgrades, prestige, idle dialogs) is in `test_progression`, `test_upgrades` and `test_prestige_idle`.
- **Save and data**: `balance.json` contents (`test_balance`), save schema, atomic writes and backups (`test_save`).
- **Puzzles and screens**: each minigame's phases, input and failure rules (`test_storage_puzzle`, `test_ram_puzzle`, `test_cpu_puzzle`), the overview, shop, hints, transitions, back navigation and licenses (`test_overview`, `test_polish`).
- **Layouts and controls**: every screen at phone, 16:9 and Steam Deck sizes (`test_layout`, via `in_viewport()`), every minigame and menu with gamepad/keyboard actions only (`test_controls`, via `press_action()` / `tap_action()`), and glyphs per device (`test_input_mode`).

Tests that touch `GameState` or screens extend `hardwire_test.gd`. It snapshots the game state and redirects saves to a test file, so the real save is never touched.
