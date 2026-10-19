# Tests

Unit tests use [GUT](https://github.com/bitwes/Gut) and live here as `test_*.gd` files extending `GutTest`.
GUT 9.7.1 is vendored in `addons/gut`. Run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

The suite must end with "All tests passed" and no `SCRIPT ERROR`: GUT silently skips a script that fails to parse.

What is covered:

- **Logic** (`logic/`): generators against the SPEC Sample tiers table (`test_sequence_gen`, `test_grid_gen`, `test_rhythm_gen`, `test_slot_generator`), `RhythmJudge` edge cases (`test_rhythm_judge`), economy, upgrade costs, prestige and idle income (`test_progression`, `test_upgrades`, `test_prestige_idle`).
- **Save and data**: `balance.json` contents (`test_balance`), save schema, atomic writes and backups (`test_save`).
- **Puzzles and screens**: each minigame's phases, input and failure rules (`test_storage_puzzle`, `test_ram_puzzle`, `test_cpu_puzzle`), the overview, shop, hints, transitions, back navigation and licenses (`test_overview`, `test_polish`).
- **Layouts and controls**: every screen at phone, 16:9 and Steam Deck sizes (`test_layout`, via `in_viewport()`), and every minigame and menu with gamepad/keyboard actions only (`test_controls`, via `press_action()` / `tap_action()`).

Tests that touch `GameState` or screens extend `hardwire_test.gd`. It snapshots the game state and redirects saves to a test file, so the real save is never touched.
