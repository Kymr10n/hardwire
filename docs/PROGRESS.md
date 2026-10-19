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
| M9 | in progress | Steam Deck and desktop: landscape, controller, Linux build, glyphs, Windows/macOS presets done; `tools/deck.sh` deploys over SSH; on-Deck check pending |

## Play-test notes

Add dated notes here after play-testing (what felt wrong, which numbers to tune). Turn agreed changes into `/spec-change`.

- Pending checks (2026-10-19): Android build on a real phone (M8); Steam Deck in game mode with controls only and touch only (M9; deploy with `tools/deck.sh`).
- 2026-10-19, desktop with a mouse: CPU taps did not register as intended. A natural click (100–150 ms) failed because 1-step taps were timed like short holds (210–390 ms at tier 1), and holds were hard to read during playback. Fixed by D-022 (judge beats and holds, not tap length; beat-length markers). Re-test: tier 1 and tier 10 with mouse, touch and gamepad; Syncopated 1.5-step holds vs taps may still be hard to tell apart.
