# Progress

Updated at the end of every milestone (by `/milestone`). `tools/check.sh` fails if code still has a `TODO(Mx)` for a milestone marked `done` here.
Status values: `todo`, `in progress`, `done`. Milestone scope and "Done when" criteria are in `docs/SPEC.md`.

| Milestone | Status | Notes |
| --- | --- | --- |
| M1 | done | Skeleton, save/load, GUT, debug stat button (2026-10-19) |
| M2 | done | Storage minigame with Reverse and Decoy; awaiting play-test |
| M3 | done | RAM minigame with Inverted and Rotated; awaiting play-test |
| M4 | done | CPU rhythm and RhythmJudge; judging reworked by D-022, re-test by ear and with a mouse pending |
| M5 | done | Overview, slot generation, gating, rewards, Boot, Settings, debug panel |
| M6 | done | Shop and upgrades |
| M7 | done | Rebuild (prestige) and idle income |
| M8 | in progress | Polish, web and Linux builds done; Android APK waits for the Android SDK licences; real-phone test pending |
| M9 | in progress | Steam Deck and desktop: landscape, controller, glyphs, Linux/Windows/macOS presets, `tools/deck.sh`, rumble (D-024) done; on-Deck check pending |

## Reviews

- 2026-10-19: whole-project review (tooling/process, spec audit, architecture) and its fixes. Verdicts: gameplay numbers match the spec three ways (spec ↔ `balance.json` ↔ tests); layering is clean (pure `logic/`, puzzles never touch `GameState`); the gate and hooks had four holes, now closed; two real bugs fixed (Storage Replay button overlap in landscape, idle offer lost on screen re-creation). Spec reconciled by D-023; rumble added by D-024. Items not applied are listed under Follow-ups.

## Follow-ups

Deferred work, each with what it needs:

- **Android (M8):** accept the Android SDK licences (`sdkmanager --licenses`), then export the APK and test on a real phone. Needs the owner.
- **Steam Deck check (M9):** deploy with `tools/deck.sh`, play every minigame once with controls only and once with touch only in Game Mode; check rumble (D-024) and glyphs. Needs the owner.
- **CPU re-test (M4, D-022/D-024):** tier 1 and tier 10 with mouse, touch and gamepad; Syncopated 1.5-step holds vs taps may still be hard to tell apart.
- **Visual check of the 2026-10-19 refactors:** the Replay button in the Storage ring centre, the overview trace node, and the CPU markers as a child control were verified by tests only; the windowed harness rendered at 1 fps during the review (display throttled). Take the screenshots when the display is active.
- **Bundle ID:** `org.hardwire.prototype` (Android and macOS presets) must become the final ID before any store release; it cannot change afterwards. Owner decision (D-021 kept the placeholder).
- **iOS preset:** none yet; waits for a Mac with current Xcode (D-008).
- **Godot built-ins instead of per-frame code** (architecture review, scope B, deferred on purpose): ResultOverlay count-up via Tween; OverviewScreen scroll-into-view via `sort_children`; StoragePad flash via a tween chain; TimerBar as a ProgressBar; touch hit-testing via `_gui_input` / signals on pads, grid, StatBar and HintOverlay (CpuPuzzle keeps `_input` for timestamps).
- **Nits from the architecture review:** `Main.wants_fullscreen` wrapper; "rebuild" naming (`Main._rebuild` vs `GameState.rebuild`); `TierRow` chips via `set_meta`; `SlotCard` allocates styleboxes per refresh; `PuzzleBase.start()` sets `time_left_s` redundantly; `CpuPuzzle` `_tone_id = -1` sentinel; construction style varies (`new(i)` vs `setup()` vs `open()`); `Synth` could mix at 22.05 kHz; `GameState` default dictionaries written twice.
- **Tooling nits:** `check.sh` boot step loads the developer's real save (not hermetic); CI restores the full export-template cache per matrix job; a `SECURITY.md`; `.claude/hooks` fail open without `python3`.
- **Play-test the balance:** time to tiers 5, 10 and 20 on a fresh save (targets: 10 min, 1 h, several sessions); fail rate per minigame; rhythm tolerance on a real phone.

## Play-test notes

Add dated notes here after play-testing (what felt wrong, which numbers to tune). Turn agreed changes into `/spec-change`.

- 2026-10-19, desktop with a mouse: CPU taps did not register as intended. A natural click (100–150 ms) failed because 1-step taps were timed like short holds (210–390 ms at tier 1), and holds were hard to read during playback. Fixed by D-022 (judge beats and holds, not tap length; beat-length markers). Re-test: tier 1 and tier 10 with mouse, touch and gamepad; Syncopated 1.5-step holds vs taps may still be hard to tell apart.
