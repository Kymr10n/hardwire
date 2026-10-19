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
| M8 | done | Polish, web and Linux builds; the Android APK and phone test are tracked in [issue #5](https://github.com/Kymr10n/hardwire/issues/5) (D-026) |
| M9 | done | Steam Deck and desktop: landscape, controller, glyphs, Linux/Windows/macOS presets, `tools/deck.sh`, rumble; Deck play-test passed 2026-10-19 (issue #6) |

**Prototype v0.1.0 released 2026-10-19 (D-026).** Next scope: the "After the prototype" sections of the spec (Steam release, Benchmark slot).

## Reviews

- 2026-10-19: whole-project review (tooling/process, spec audit, architecture) and its fixes. Verdicts: gameplay numbers match the spec three ways (spec ↔ `balance.json` ↔ tests); layering is clean (pure `logic/`, puzzles never touch `GameState`); the gate and hooks had four holes, now closed; two real bugs fixed (Storage Replay button overlap in landscape, idle offer lost on screen re-creation). Spec reconciled by D-023; rumble added by D-024. Items not applied are listed under Follow-ups.
- 2026-10-19, later: the review's deferred items applied. Per-frame code replaced by Godot built-ins (Tween count-up and pad flash, `sort_children` scroll, `ProgressBar` timer, pointer input through `_gui_input` with `tapped` / `cell_activated` signals; CpuPuzzle keeps `_input` for its timestamps); the architecture nits; the tooling nits (hermetic gate, one CI export job, `SECURITY.md`, hooks block without python3). Visual check done at 1280×800 and 540×960: Replay button centred in the ring, trace line and tier nodes, CPU markers, result count-up, timer bar all as intended. Tests: 208 in 23 scripts.

## Follow-ups

Deferred work, each with what it needs:

- **Android:** [issue #5](https://github.com/Kymr10n/hardwire/issues/5): accept the SDK licences, export the APK, test on a real phone. Needs the owner.
- **CPU re-test (M4, D-022/D-024):** tier 1 and tier 10 with mouse, touch and gamepad; Syncopated 1.5-step holds vs taps may still be hard to tell apart.
- **Bundle ID:** `org.hardwire.prototype` (Android and macOS presets) must become the final ID before any store release; it cannot change afterwards. Owner decision (D-021 kept the placeholder).
- **iOS preset:** none yet; waits for a Mac with current Xcode (D-008).
- **Private vulnerability reporting:** `SECURITY.md` points at GitHub's private report form; the owner enables it under Settings → Code security (`gh api -X PUT repos/Kymr10n/hardwire/private-vulnerability-reporting`).
- **Play-test the balance:** time to tiers 5, 10 and 20 on a fresh save (targets: 10 min, 1 h, several sessions); fail rate per minigame; rhythm tolerance on a real phone.

## Play-test notes

Add dated notes here after play-testing (what felt wrong, which numbers to tune). Turn agreed changes into `/spec-change`.

- 2026-10-19, desktop with a mouse: CPU taps did not register as intended. A natural click (100–150 ms) failed because 1-step taps were timed like short holds (210–390 ms at tier 1), and holds were hard to read during playback. Fixed by D-022 (judge beats and holds, not tap length; beat-length markers). Re-test: tier 1 and tier 10 with mouse, touch and gamepad; Syncopated 1.5-step holds vs taps may still be hard to tell apart.
