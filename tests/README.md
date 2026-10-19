# Tests

Unit tests use [GUT](https://github.com/bitwes/Gut) and live here as `test_*.gd` files extending `GutTest`.
Install GUT into `addons/gut` first (see the project README), then run:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

Planned coverage: everything in `logic/` — slot generation and the Sample tiers table (M5), sequence/grid/rhythm generators (M2–M4), `RhythmJudge` edge cases (M4), economy, upgrade costs, prestige and idle income (M5–M7).
