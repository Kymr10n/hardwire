# Progress

Updated at the end of every milestone (by `/milestone`). `tools/check.sh` fails if code still has a `TODO(Mx)` for a milestone marked `done` here.
Status values: `todo`, `in progress`, `done`. Milestone scope and "Done when" criteria are in `docs/SPEC.md`.

| Milestone | Status | Notes |
| --- | --- | --- |
| M1 | done | Skeleton, save/load, GUT, debug stat button (2026-10-19) |
| M2 | done | Storage minigame with Reverse and Decoy; awaiting play-test |
| M3 | done | RAM minigame with Inverted and Rotated; awaiting play-test |
| M4 | done | CPU rhythm and RhythmJudge; judged as you play with wider tolerance since D-030, re-test pending |
| M5 | done | Overview, slot generation, gating, rewards, Boot, Settings, debug panel |
| M6 | done | Shop and upgrades |
| M7 | done | Rebuild (prestige) and idle income |
| M8 | done | Polish, web and Linux builds; the Android APK and phone test are tracked in [issue #5](https://github.com/Kymr10n/hardwire/issues/5) (D-026) |
| M9 | done | Steam Deck and desktop: landscape, controller, glyphs, Linux/Windows/macOS presets, `tools/deck.sh`, rumble; Deck play-test passed 2026-10-19 (issue #6) |
| M10 | in progress | Steam release preparation (D-032): save folder, Windows exe metadata and `tools/steam_upload.sh` done; the first Steam install waits for the App ID |

**Prototype v0.1.0 released 2026-10-19 (D-026).** Next scope: the "After the prototype" sections of the spec (Steam release, Benchmark slot).

## Reviews

- 2026-10-19: whole-project review (tooling/process, spec audit, architecture) and its fixes. Verdicts: gameplay numbers match the spec three ways (spec ↔ `balance.json` ↔ tests); layering is clean (pure `logic/`, puzzles never touch `GameState`); the gate and hooks had four holes, now closed; two real bugs fixed (Storage Replay button overlap in landscape, idle offer lost on screen re-creation). Spec reconciled by D-023; rumble added by D-024. Items not applied are listed under Follow-ups.
- 2026-10-19, later: the review's deferred items applied. Per-frame code replaced by Godot built-ins (Tween count-up and pad flash, `sort_children` scroll, `ProgressBar` timer, pointer input through `_gui_input` with `tapped` / `cell_activated` signals; CpuPuzzle keeps `_input` for its timestamps); the architecture nits; the tooling nits (hermetic gate, one CI export job, `SECURITY.md`, hooks block without python3). Visual check done at 1280×800 and 540×960: Replay button centred in the ring, trace line and tier nodes, CPU markers, result count-up, timer bar all as intended. Tests: 208 in 23 scripts.
- 2026-10-19: ambient score (D-027–D-029): reviewer and spec-auditor findings fixed (test state leak, pause keeps effects tested, spec numbers in tests, scale and paused screens named in the spec); the owner listened on desktop and approved. Remaining items are under Follow-ups.
- 2026-10-19: renamed to "Hardwire: Boot Sequence" (D-033) to stay apart from "Hardwired" (Lostbyte) on Steam; spec audit fixed (log, CHANGELOG, test coverage).

## Follow-ups

Deferred work, each with what it needs:

- **Android:** [issue #5](https://github.com/Kymr10n/hardwire/issues/5): accept the SDK licences, export the APK, test on a real phone. Needs the owner.
- **CPU re-test (M4, D-030):** tier 1 and tier 10 with mouse, touch and gamepad after the judge-as-you-play rework; is 40% at tier 1 too loose? Syncopated 1.5-step holds vs taps may still be hard to tell apart.
- **Bundle ID:** `org.hardwire.prototype` (Android and macOS presets) must become the final ID before any store release; it cannot change afterwards. Owner decision (D-021 kept the placeholder).
- **iOS preset:** none yet; waits for a Mac with current Xcode (D-008).
- **Private vulnerability reporting:** `SECURITY.md` points at GitHub's private report form; the owner enables it under Settings → Code security (`gh api -X PUT repos/Kymr10n/hardwire/private-vulnerability-reporting`).
- **Name:** reserve "Hardwire: Boot Sequence" in Steamworks (and later Google Play Console and App Store Connect). The macOS bundle takes its name from `config/name`; check it at the first macOS export (D-008). Needs the owner.
- **Steam (M10):** create the Steamworks app; set depots, launch options, Steam Input, Linux Runtime and Auto-Cloud from the spec table; fill `tools/steam.local.env`; run `tools/steam_upload.sh --preview`, then a real upload; install from the Steam client on PC and Steam Deck. Copy the Deck's 0.1.0 save to `~/.local/share/Hardwire` if wanted. Needs the owner and the App ID.
- **Ambient score on devices:** listen and profile on the web export, Steam Deck and Android. The score keeps 3–4 GDScript voices mixing on the main thread (single-threaded on web); if it is too heavy, drop the bass harmonic voice first.
- **Ambient score code (review, should-fix):** schedule each bar's notes with per-voice `delay_ms` instead of per-frame dispatch (removes frame jitter on the hi-hat and the event index); resolve attack/release defaults once in `Synth._add_voice` and store the kick glide as a per-sample step; one `_pick_positions` helper for pads and leads; seed bars with `hash([seed, bar])` and drop `music_seed_stride`; `music_bass_min_midi`/`max_midi` are test-only (move into the test or enforce); `music_kick_beats` repeats the bass beats; the debug time scale also speeds up the score.
- **Play-test the balance:** time to tiers 5, 10 and 20 on a fresh save (targets: 10 min, 1 h, several sessions); fail rate per minigame; rhythm tolerance on a real phone.

## Play-test notes

Add dated notes here after play-testing (what felt wrong, which numbers to tune). Turn agreed changes into `/spec-change`.

- 2026-10-19, Steam Deck: the owner wants full immersion: rumble on every button and while a puzzle plays back. D-034: the Haptics autoload hooks every button; Storage pads and the RAM pattern rumble while lit (decoys weaker), like the CPU tile. Re-test: a buy must buzz once; is the RAM rumble (up to 2.5 s) too much? Tests: 228 in 24 scripts.
- 2026-10-19, Steam Deck: the CPU minigame was not fun: no feedback while playing (pass/fail arrived 600 ms after the last release, without saying which beat was wrong) and the timing felt too strict. D-030: judged as you play, the first miss ends the attempt with a red marker and the reason ("Beat 3 too late"), success at the last release, tolerance 40% → 25% with a 100 ms floor. Re-test: tier 1 and tier 10 with touch and gamepad; is the tolerance now too loose at tier 1? Tests: 214 in 23 scripts.
- 2026-10-19, Steam Deck touchscreen: swiping the overview list did not scroll it. Cause: `ScrollContainer` drag-scrolls on (emulated) mouse events, and the slot cards, as Buttons with `MOUSE_FILTER_STOP`, swallowed them; the shop list scrolled because its cards are PanelContainers. Fixed: buttons in lists pass pointer events up (the engine cancels the press when a scroll starts) and lists have a `scroll_deadzone` (theme) so a wobbly tap is still a tap. Re-test: swipe and tap on the overview and the shop.
- 2026-10-19, desktop with a mouse: CPU taps did not register as intended. A natural click (100–150 ms) failed because 1-step taps were timed like short holds (210–390 ms at tier 1), and holds were hard to read during playback. Fixed by D-022 (judge beats and holds, not tap length; beat-length markers). Re-test: tier 1 and tier 10 with mouse, touch and gamepad; Syncopated 1.5-step holds vs taps may still be hard to tell apart.
