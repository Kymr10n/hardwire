# Hardwire — Game Design Spec

As of 2026-10-19. **Source of truth for implementation.** Build it milestone by milestone (see "Milestones and acceptance criteria"); progress is tracked in `docs/PROGRESS.md`. Change it only through `/spec-change`, which also records the change in `docs/DECISIONS.md`.

## Overview

Hardwire is an endless incremental puzzle game for phones, PC and Steam Deck, built in Godot 4. The player upgrades a computer by solving three short memory and timing minigames. Each minigame raises one stat (RAM, CPU or Storage), and higher stats unlock harder puzzle slots that pay out more.

| Decision | Choice |
| --- | --- |
| Engine | Godot 4.7.2 (pinned in `tools/versions.env`), GDScript, Compatibility renderer |
| Platforms | Android, iOS, Windows, Linux, macOS, Steam Deck (native Linux build), plus Web — see Platforms and input |
| Orientation | Phones portrait; PC and Steam Deck landscape. One layout code path per screen adapts to both |
| Input | Touch, mouse, keyboard and gamepad, all through InputMap actions |
| Art | Minimal flat circuit-board look, no drawn assets |
| Audio | Synthesized tones generated in code, no audio files needed |
| Save | Local JSON in `user://` |
| Prototype scope | All three minigames, overview with tiers, upgrade shop, prestige, idle income |

Design pillars:

- **Short sessions.** One puzzle takes 10 to 40 seconds, so the game works in a tram or a queue.
- **Always fair.** A failure costs nothing; the player gets a fresh sequence at the same difficulty right away.
- **Endless through breadth, not only length.** Difficulty grows by sequence length and speed until human limits, then by new puzzle dimensions and modifiers.
- **Data-driven balance.** Every number in this spec lives in one config file (`data/balance.json`), so balancing never needs code changes.

## Platforms and input

Every screen and minigame must be fully playable with touch, mouse, keyboard and gamepad, and must lay out correctly in portrait (phones) and landscape (PC, Steam Deck). Gameplay code reads InputMap actions only, never raw keys or buttons.

| Target | Export | Screen | Primary input | Notes |
| --- | --- | --- | --- | --- |
| Android | APK / AAB | Portrait, locked | Touch | Built from Linux |
| iOS | Xcode project | Portrait, locked | Touch | Needs macOS with Xcode 26 (D-008) |
| Windows | x86_64 | Landscape window, resizable, default 1280 × 800 | Mouse, keyboard, gamepad | |
| Linux | x86_64 | Same as Windows | Mouse, keyboard, gamepad | Same build runs natively on Steam Deck |
| macOS | Universal | Same as Windows | Mouse, keyboard, gamepad | Signing and notarization need a Mac (D-008) |
| Steam Deck | Linux x86_64 build | 1280 × 800 landscape, fullscreen | Gamepad, touch | Must meet the Deck Verified checklist below |
| Web | HTML5, single-threaded | Follows the browser window | Touch, mouse, keyboard | Extra target (D-021) |

**Layout.** The viewport reference is 1080 × 1920 (portrait) or 1920 × 1080 (landscape), picked from the window aspect, with stretch mode `canvas_items` and aspect `expand`. Each screen has one code path that arranges its parts by orientation (see Screens and UX flow > Landscape). The switch lives in one place (`Main` and `Ui.is_landscape()`).

**Legibility.** Minimum font size is 32 px at the reference size (about 21 px on a 1280 × 800 Steam Deck screen). Tap and click targets are at least 120 px at the reference size.

**Input actions.** Godot's UI actions plus two game actions (`commit`, `debug_panel`), defined in `project.godot`:

| Action | Touch / mouse | Keyboard | Gamepad |
| --- | --- | --- | --- |
| Navigate menus and puzzles (`ui_up` / `ui_down` / `ui_left` / `ui_right`) | Tap / click | Arrow keys, Tab | D-pad, left stick |
| Confirm (`ui_accept`) | Tap / click | Enter, Space | A (south button) |
| Back (`ui_cancel`) | Back button on screen | Esc, Backspace | B (east button) |
| Storage pad | Tap pad | Move focus to the pad, Enter / Space | Move focus to the pad, A |
| RAM cursor and toggle | Tap cell | Arrow keys move, Enter / Space toggles | D-pad moves, A toggles |
| RAM commit (`commit`) | Commit button | C | Y (north button) |
| CPU tile | Hold tile | Hold Space or Enter | Hold A |
| Debug panel (`debug_panel`, debug builds) | Tap the stat bar 5 times | F1 | View (Select) |

The focus outline shows only for keyboard and gamepad input; when the overview opens, focus starts on the first unsolved slot of the newest unlocked tier. Storage pads keep their ring on every input method (D-021).

**Glyphs.** On-screen prompts show the glyphs of the last-used input device: none for touch ("Tap to …"), keys for keyboard and mouse ("Click or press Enter to …"), A/B/X/Y for gamepad (Xbox layout, which matches Steam Deck). Keyboard prompts never appear while a gamepad is in use.

**Steam Deck Verified checklist** ([Valve](https://partner.steamgames.com/doc/steamhardware/compat)):

- Full controller support in the default configuration, with matching glyphs.
- Runs at 1280 × 800, smallest text at least 9 px (target 12 px or more).
- No launcher, no unsupported-platform warnings.
- No text entry, so no on-screen keyboard is needed.
- At least 30 fps at 800p; the game caps at 60 fps (`application/run/max_fps`).

**Haptics.** Phones use `Input.vibrate_handheld`; gamepads use `Input.start_joy_vibration`. Both go through the Haptics autoload and respect the setting. Every input gives a light pulse; the CPU minigame rumbles with the rhythm (see Minigame: CPU > Haptics); results give a pulse pattern (see Result overlay). Lengths and strengths live in `balance.json` → `haptics`.

## Core loop

The player picks an unlocked slot, watches a sequence, reproduces it, and earns stats and Cycles on success. On failure the same slot immediately shows a new sequence at the same difficulty, and the player can retry or leave without penalty.

```
Pick a slot ──> Watch ──> Reproduce ──> Correct in time?
     ^            ^                        │yes      │no
     │            └── fresh sequence, ─────┼─────────┘
     │                same difficulty      v
     └──── back to overview ────── Earn stats + Cycles
     │
     └──> Shop and prestige (spend Cycles)
```

Every attempt has two phases. In the **watch phase** input is disabled and the sequence plays. In the **input phase** a timer bar runs and the player reproduces what they saw or heard. A short countdown ("3, 2, 1" over 1.5 s) precedes the watch phase so the player is ready.

## Stats, currency and slot gating

The player has three stats that only go up until a prestige, plus one spendable currency. A slot unlocks only when every stat meets that slot's requirement on its own, so no minigame can be skipped.

| Resource | Raised by | Used for | Theme |
| --- | --- | --- | --- |
| RAM | Pattern grid minigame | Slot requirements | Holding a snapshot in working memory |
| CPU | Rhythm minigame | Slot requirements | Clock cycles, timing |
| STO (Storage) | Color sequence minigame | Slot requirements | Writing data in order |
| Cycles | Every solve, any minigame; idle income | Upgrade shop | Compute time earned |
| Cores | Prestige only | Permanent reward multiplier | Hardware kept across rebuilds |

Gating rule, per slot:

- Unlocked when `ram >= req.ram and cpu >= req.cpu and sto >= req.sto`.
- Locked slots stay visible, greyed out, and show the missing amount per stat (for example "CPU 4 more").
- Stats are integers and are never spent. Upgrades cost Cycles only.

A solve credits stat points to the slot's own stat and Cycles to the wallet. The first solve of each slot pays double, so a new tier always feels rewarding. Replays pay the normal amount, which grows with tier, so replaying the highest unlocked tier is always the most efficient way to grind.

## Minigame: Storage (color sequence)

The game lights a sequence of colored pads, and the player taps them back in the same order. It raises STO.

**Layout.** Pads sit in a ring around the screen center, each at least 160 px across; on keyboard and gamepad the focus moves between them (see Platforms and input). Every pad has a distinct color, a distinct tone and a small symbol (circle, triangle, square, and so on) so the game stays playable for colorblind players.

**Watch phase.** Each pad lights for `show_ms` with its tone, followed by a 150 ms gap. The same pad may appear twice in a row; the gap makes the repeat visible.

**Input phase.**

- The player taps pads; each tap lights the pad and plays its tone.
- A wrong pad fails the attempt immediately.
- The attempt also fails if the timer runs out. Time limit = `length × input_s_per_item`.
- The attempt succeeds as soon as the last correct pad is tapped.

**Difficulty knobs.** Sequence length, pad count and `show_ms`, all driven by tier (see Difficulty curve).

**Modifiers** (from tier 8, see Difficulty curve):

- *Reverse:* enter the sequence back to front.
- *Decoy:* one extra pad flashes dimly, with a quieter tone, during playback and must be ignored. It appears between two real items (never first or last) and on a pad different from both neighbors.

## Minigame: RAM (pattern grid)

The game briefly shows a black-and-white pattern on a square grid, then hides it, and the player recreates it from memory. It raises RAM.

**Layout.** A square grid fills the screen width minus margins. Cells are at least 120 px, which caps a phone layout at about 7 × 7.

**Watch phase.** `filled` random cells light up for `show_ms`, then all cells go dark.

**Input phase.**

- Tapping a cell toggles it on or off, so mistakes can be corrected.
- A counter shows "cells set / cells needed". Cells needed is `filled`, or `n² − filled` with the Inverted modifier.
- A **Commit** button checks the grid. It is enabled once the set count equals cells needed.
- The attempt succeeds if the set cells match the pattern exactly. Otherwise, or on timeout, it fails and the correct pattern flashes for 1 s before the new attempt starts.

**Difficulty knobs.** Grid size, number of filled cells and `show_ms`.

**Modifiers** (from tier 8):

- *Inverted:* set the cells that were dark instead of the lit ones.
- *Rotated:* enter the pattern rotated 90° clockwise; a clockwise arrow icon above the grid shows the rotation for the whole attempt.

## Minigame: CPU (rhythm)

A central tile plays a rhythm of on and off phases, and the player mimics it by holding and releasing that tile. Timing is judged on relative intervals with a tolerance, never on absolute timestamps. It raises CPU.

**Rhythm model.** A rhythm is a list of alternating segments, measured in steps of `step_ms`:

- `beats` on-segments, each 1 to 3 steps long (1 step = a tap, 2 to 3 steps = a hold).
- Off-segments between them, each 1 to 2 steps long.
- No off-segment before the first beat or after the last.

**Watch phase.** The tile lights and plays a steady tone for each on-segment and goes dark for each off-segment. Under the tile, one marker per beat shows its length: a dot for a tap, a bar as long as its steps for a hold. Markers fill as beats play, and again as the player presses.

**Haptics.** During playback the controller rumbles for each on-segment, exactly as long as the tile is lit (phones: one vibration per beat), so a tap is a short buzz and a hold a long one. Under Audio only playback does not rumble: only the tone plays. During input the controller rumbles for as long as the tile is held.

**Input phase.**

- The clock starts at the player's first press. There is no count-in and no need to hit a beat grid.
- Each press and release is timestamped with `Time.get_ticks_usec()` in `_input`, not in `_process`.
- Input ends at the release of beat number `beats` (success) or at the first miss (failure, see Judging).
- It also ends, as a failure, once no input could still pass: when the time since the first press exceeds the longest passing rhythm (every beat interval and the last beat at their upper tolerance). A uniformly slow but in-tolerance player is never cut off. This window also caps how long the last beat, even a tap, may be held.
- With no first press within 5 s, the attempt times out.
- **Failure:** the tile replays the target rhythm silently, compressed to fit the 1 s answer reveal.

**Judging.**

Judged as you play: every check is made the moment the input determines it.

1. **Beats:** for each beat but the last, the time from its press to the next press is compared with its target (its on-segment plus the following off-segment), as soon as the next press lands.
2. **Holds:** for each hold (an on-segment longer than one step), the time from press to release is compared with the hold's length, as soon as it is released. Taps (one step or shorter) are not timed, so a quick tap or click is fine.
3. A comparison passes if `abs(actual − target) <= max(100 ms, tolerance × target)`.
4. The first failing comparison ends the attempt: the marker of the beat whose press came late or early (or whose hold was wrong) turns red, and the hint line above the tile says why: "Beat 3 too late", "Beat 3 too early", "Beat 2 held too short", "Beat 2 held too long" (beats counted from 1).
5. Every beat released without a miss → success. If the input window runs out first (a press never released, or too few presses), the attempt fails.

The judge is a pure function with unit tests, because it decides whether the minigame feels fair.

**Difficulty knobs.** Number of beats, `step_ms` (tempo) and `tolerance`.

**Modifiers** (from tier 8):

- *Audio only:* the tile stays dark during playback; only the tone plays. The beat markers are plain dots that do not fill during playback, only for the player's presses.
- *Syncopated:* on- and off-segments may also be 0.5 or 1.5 steps long, and every syncopated rhythm contains at least one such half-step segment.

## Difficulty curve and slot tiers

The overview is an endless list of tiers T = 1, 2, 3, …, each with one slot per minigame. Requirements grow quadratically while rewards grow linearly, so first solves alone carry the player to tier 4, and after that the shop and prestige carry the grind.

**Tier generation.** Tiers are computed on demand from formulas, never stored. The overview shows every unlocked tier plus the next two locked ones. A slot's identity (tier, minigame, modifier) is deterministic from a hash of (tier, minigame): FNV-1a (32 bit) of the text `"<tier>:<type>"`. Its low 16 bits decide whether the slot has a modifier and the high 16 bits pick which one, so slots look the same after a restart and on every platform. Each attempt's sequence uses a fresh random seed.

**Economy formulas** (per stat, per slot):

```
req(T)    = 2 × (T − 1)²
reward(T) = T + 1
cycles(T) = 5 × T
```

First solve of a slot pays 2 × reward and 2 × Cycles. Modifier slots pay a further 1.5 ×. Upgrades and Cores multiply on top. All factors multiply, and the result is rounded to the nearest integer:

```
stat gain   = round(reward(T) × first × modifier × (1 + 0.10 × Overclock) × (1 + 0.25 × Cores))
cycles gain = round(cycles(T) × first × modifier × (1 + 0.10 × Cycle miner) × (1 + 0.25 × Cores))
```

**Minigame formulas:**

- Storage: `length = min(3 + floor(T/2), 12)`; pads = 4 (T1 to 3), 5 (T4 to 7), 6 (T8 to 12), 8 (T13+); `show_ms = max(300, 700 − 25(T−1))`; `input_s_per_item = max(0.8, 1.5 − 0.03(T−1))`.
- RAM: grid = 3 × 3 (T1 to 4), 4 × 4 (T5 to 9), 5 × 5 (T10 to 15), 6 × 6 (T16+); `filled = min(3 + floor((T−1)/2), floor(0.45 × n²))`; `show_ms = max(1000, 2500 − 100(T−1))`; input time = 4 s + 0.8 s per cell needed (equal to `filled` without the Inverted modifier).
- CPU: `beats = min(3 + floor(T/3), 10)`; `step_ms = max(150, 300 − 8(T−1))`; `tolerance = max(0.25, 0.40 − 0.0075(T−1))`.

**Sample tiers** (computed from the formulas above; use as test fixtures):

| Tier | Req per stat | Stat reward first / replay | Cycles first / replay | Storage length · pads · show ms | RAM grid · filled · show ms | CPU beats · step ms · tolerance |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 0 | 4 / 2 | 10 / 5 | 3 · 4 · 700 | 3×3 · 3 · 2500 | 3 · 300 · 40% |
| 2 | 2 | 6 / 3 | 20 / 10 | 4 · 4 · 675 | 3×3 · 3 · 2400 | 3 · 292 · 39.25% |
| 3 | 8 | 8 / 4 | 30 / 15 | 4 · 4 · 650 | 3×3 · 4 · 2300 | 4 · 284 · 38.5% |
| 5 | 32 | 12 / 6 | 50 / 25 | 5 · 5 · 600 | 4×4 · 5 · 2100 | 4 · 268 · 37% |
| 10 | 162 | 22 / 11 | 100 / 50 | 8 · 6 · 475 | 5×5 · 7 · 1600 | 6 · 228 · 33.25% |
| 20 | 722 | 42 / 21 | 200 / 100 | 12 · 8 · 300 | 6×6 · 12 · 1000 | 9 · 150 · 25.75% |

Without upgrades or modifiers, reaching tier 10 takes about 8 replays per minigame in total (1 to 2 per tier from tier 4), and tier 20 about 24.

**Modifiers.** From tier 8 a slot may carry one modifier. The chance is `min(0.8, 0.3 + 0.025(T−8))`, decided by the slot's hash. Tiers 8 to 13 draw from the first modifier of each minigame (Reverse, Inverted, Audio only); tier 14 onward adds the second (Decoy, Rotated, Syncopated). A modifier slot shows its icon and name on the overview and in the puzzle header; the names are Reverse, Decoy, Inverted, Rotated, Audio only and Syncopated.

## Upgrade shop

The shop sells leveled upgrades for Cycles. Assist upgrades make puzzles easier and are capped; economy upgrades boost rewards and are uncapped. Cost of the next level = `round(base × growth^level)` Cycles, where `level` is the current level.

| Upgrade | Effect per level | Max level | Base cost | Growth |
| --- | --- | --- | --- | --- |
| Replay buffer | Storage: one extra "Replay" button use per attempt | 2 | 50 | 3.0 |
| Longer exposure | RAM: +10% `show_ms` | 5 | 30 | 1.8 |
| Metronome | CPU: +3 percentage points tolerance | 5 | 30 | 1.8 |
| Time dilation | All: +15% input time limit | 5 | 40 | 1.9 |
| Overclock | All: +10% stat rewards | none | 100 | 2.2 |
| Cycle miner | All: +10% Cycles | none | 80 | 2.0 |

Assist upgrades are applied when an attempt is built, after the tier formulas (and after their floors and caps). The puzzle screen copies the upgrade levels into the `SlotDef`, so puzzles still never read `GameState`. The shop shows each upgrade's current level, next effect and cost, and greys out what the player cannot afford.

- *Replay buffer:* during the Storage input phase a "Replay" button shows the uses left. A replay plays the sequence again, resets the entered progress to zero and restarts the timer at its full length.
- *Time dilation* multiplies the Storage and RAM time limits. CPU has no fixed input limit, so there it multiplies the first-press timeout.

## Prestige ("Rebuild")

Once the player has solved any tier 10 slot, they can Rebuild: reset progress in exchange for Cores, a permanent multiplier. Each Rebuild should reach the previous best tier noticeably faster.

- **Cores earned** = `max(0, highest_tier_solved − 9)`, so tier 10 gives 1 Core and tier 20 gives 11.
- **Effect:** every Core adds +25% to stat rewards and Cycles, additively. Total multiplier = `1 + 0.25 × total_cores`.
- **Reset:** stats, Cycles, upgrade levels and first-solve flags.
- **Kept:** Cores, best tier ever reached, settings, lifetime statistics and the first-run hints already seen.
- A confirm dialog shows Cores to be gained and the new multiplier before the reset.

## Idle income

While the app is closed, the player earns Cycles (never stats), capped at 8 hours, so coming back always pays something but puzzles remain the only way to progress.

- **Rate:** `idle_cycles_per_hour = 6 × cycles(T_max)`, where T_max is the highest tier with at least one solved slot. That equals about 6 replays per hour, well below active play.
- **Multipliers:** Cycle miner and Cores apply; Overclock does not, because it boosts stats only.
- **Cap:** 8 hours of earnings. Nothing accrues before the first solve.
- **Amount:** `round(rate × min(hours away, 8) × (1 + 0.10 × Cycle miner) × (1 + 0.25 × Cores))`.
- **Collection:** on app start or resume, if more than 5 minutes passed, a "While you were away" dialog shows the amount and a Collect button. It appears on the overview, never over a running puzzle; after a resume during a puzzle it waits until the player returns to the overview.
- **Clock:** elapsed time = now − `last_seen`, using the device's Unix time. A negative or missing value counts as zero. Clock tampering is accepted for the prototype.

## Screens and UX flow

The prototype has five screens around one hub, the overview. Every screen works in portrait and landscape and with every input method (see Platforms and input).

| Screen | Contents | Leads to |
| --- | --- | --- |
| Boot | Title, "Press any button" ("Tap to start" on touch), loads the save | Overview |
| Overview | Top bar with RAM, CPU, STO, Cycles and Cores (compact above 9999: 12.3K, 4.56M); vertical scroll list of tier rows (tier 1 at the top), newest unlocked tier in view on open; each row = tier number, requirement chips (accent-coloured while unmet) and 3 slot cards (RAM, CPU, STO); bottom bar with Shop, Rebuild, Settings and, on PC, Quit (saves and closes) | Puzzle, Shop, Rebuild dialog, Settings |
| Puzzle | Header with minigame name, tier, modifier and a back button; phase label ("Watch" / "Your turn"); timer bar; the minigame area; result overlay | Overview |
| Shop | List of upgrade cards, Cycles balance on top | Overview |
| Settings | Sound on or off, haptics on or off, licenses (full texts of Hardwire, the font and Godot with its third-party components; the text scrolls with the D-pad or arrows; Back returns to Settings), reset save (with confirm) | Overview, Licenses |

**Slot card states:** locked (greyed, shows missing stats), unlocked and never solved (accent border, "NEW" badge), solved (normal), modifier (icon in the corner). Unlocked cards show what the next solve pays (+stat, +Cycles).

**Result overlay:**

- Success: "Write complete", the stat and Cycles gained (counting up over 0.6 s), a "First solve ×2" note on a first solve and a note if a new tier unlocked, then buttons "Again" (same slot, new sequence) and "Overview".
- Failure: "Corrupted", the correct answer shown for 1 s, then the next attempt starts automatically. The back button is always available.
- Haptics: a success gives a short double pulse, a failure one long pulse (every minigame).

**Feedback on every input:** pad or cell flash, its tone, and a light haptic pulse (phone vibration or gamepad rumble).

**Landscape:** the same screens with one code path each; a window that changes orientation re-creates the current screen, and a running attempt restarts with a fresh sequence (no penalty). The puzzle screen puts header, phase label and timer in a side panel next to the puzzle; the overview puts the stats and the Shop / Rebuild / Settings buttons in a sidebar next to the tier list; the shop shows two columns; other screens use a centered column.

On PC, Settings adds "Fullscreen" and the overview adds "Quit"; B on the overview never quits. With the `SteamDeck=1` environment variable (set by Steam on the Deck) the game starts fullscreen.

**First run:** each minigame shows a one-line instruction overlay the first time it opens ("Repeat the sequence", "Recreate the pattern", "Copy the rhythm by holding the tile"). The attempt starts when the player taps the overlay; the hint is then recorded in `seen_tutorials`.

**Modifier hints:** a modifier slot shows one dim line above the play area: "Set the dark cells" (Inverted), "Enter it rotated" (Rotated, next to the arrow icon), "Listen" (Audio only), "Half steps" (Syncopated). Reverse and Decoy show only their name in the header.

**Transitions:** each new screen fades in over 150 ms.

**Back button (Android):** returns to the overview from any other screen and quits from the overview or boot screen.

## Visual and audio style

The look is a dark, flat circuit board drawn entirely with Godot shapes and one font, so the prototype needs no art assets. The sound is simple synthesized tones generated at runtime.

**Visuals:**

- Background near-black blue-grey; thin trace lines in a muted green-grey connect the tier rows on the overview.
- One accent color per stat, used for its numbers, slot borders and minigame header: RAM cyan, CPU magenta, STO amber.
- Storage pads use an 8-color colorblind-safe palette, each paired with a symbol.
- Shapes are rounded rectangles; lit states glow by brightening and scaling to 105% over 80 ms. No gradients or textures.
- One monospace font under the SIL Open Font License (for example JetBrains Mono), bundled with the project.
- All colors, sizes and durations live in a theme resource so the style can be changed in one place.

**Audio** (generated with `AudioStreamGenerator`, no files):

- A quiet ambient score runs on the Overview and Puzzle screens (dialogs and results on them
  included) and pauses on Boot, Shop, Settings, Licenses and the debug menu. It is a slow
  four-bar bass progression (D, C, G, A) of smooth sine tones with a faint octave harmonic, one or
  two softly enveloped upper notes and two or three short high notes (three octaves up, on
  eighth-note positions) per bar, all from the minor pentatonic of that bar's root. A soft
  half-time beat underneath: a sine kick with a pitch drop on beats 1 and 3, a short noise hi-hat
  on every off-beat. Seeded variation changes note choices and spacing each session; the beat is
  fixed.
- The score and all sound effects respect the Sound setting. Music tuning lives in
  `balance.json` → `audio`.
- Storage pads: one note each from a pentatonic scale, so any sequence sounds pleasant.
- RAM: a soft click on toggle.
- CPU tile: a steady sine tone while lit or held.
- Success: a short rising arpeggio. Failure: a 200 ms noise burst ("glitch").

## Save system

The game saves one JSON file to `user://save.json` after every solve, purchase, prestige and settings change, and on window close or app pause (so `last_seen` is current). Godot maps `user://` to the right per-user folder on every target platform (browser storage on the web), so the same code works everywhere.

```json
{
  "version": 1,
  "stats": { "ram": 0, "cpu": 0, "sto": 0 },
  "cycles": 0,
  "cores": 0,
  "last_seen": 0,
  "upgrades": { "replay_buffer": 0, "longer_exposure": 0, "metronome": 0, "time_dilation": 0, "overclock": 0, "cycle_miner": 0 },
  "solved_slots": ["3:ram", "3:cpu"],
  "best_tier_ever": 0,
  "seen_tutorials": ["sto"],
  "settings": { "sound": true, "haptics": true },
  "lifetime": { "solves": 0, "fails": 0, "rebuilds": 0 }
}
```

- Write to a temporary file, then rename it over the old one, so a crash mid-write never corrupts the save.
- `version` allows migrations later; on an unknown or broken file the game backs it up as `save.bak.json` and starts fresh.

## Technical architecture (Godot 4)

The code splits pure logic (generators, judges, economy) from presentation (scenes), so the rules can be unit-tested headless and Claude Code rarely needs the Godot editor. UI is built mostly in code on top of minimal `.tscn` files.

**Project settings:**

- Renderer: Compatibility (`gl_compatibility`).
- Window: 1080 × 1920 reference viewport (1920 × 1080 in landscape), stretch mode `canvas_items`, aspect `expand`; phones locked to portrait; desktop window 1280 × 800 by default. Test phone layout with `--resolution 540x960`.
- Input: pointer input is touch, with the mouse emulated (`emulate_touch_from_mouse`); keyboard and gamepad use InputMap actions (see Platforms and input). Only the InputMode autoload looks at raw device events, for glyphs.

**Folder structure:**

```
res://
  project.godot
  data/
    balance.json          # every number from this spec
  autoload/
    GameState.gd          # stats, cycles, cores, upgrades, solved slots; emits signals
    SaveManager.gd        # load/save user://save.json, atomic write, migrations
    Balance.gd            # loads balance.json, exposes formula functions
    Synth.gd              # AudioStreamGenerator tones, success/fail sounds
    Haptics.gd            # phone vibration + gamepad rumble, respects settings
    InputMode.gd          # last-used device and its glyphs for prompts
  logic/                  # pure GDScript, no nodes, fully unit-tested
    SlotDef.gd            # data class: tier, type, modifier, requirements, rewards
    SlotGenerator.gd      # (tier, type) -> SlotDef incl. modifier, requirements, rewards
    SequenceGen.gd        # Storage attempt content from seed + SlotDef
    GridGen.gd            # RAM attempt content
    RhythmGen.gd          # CPU attempt content
    RhythmJudge.gd        # timestamps + target -> pass/fail per segment
    Economy.gd            # rewards, costs, multipliers, prestige cores, idle income
    Progress.gd           # gating, tiers, rebuild eligibility, idle offer over the player state
  scenes/
    Main.tscn, Main.gd    # holds the current screen, orientation, transitions, back, idle offer
    screens/              # Boot, Overview, Puzzle, Shop, Settings, Licenses, DebugMenu
    puzzles/
      PuzzleBase.gd       # state machine COUNTDOWN -> WATCH -> INPUT -> RESULT; signals solved/failed
      StoragePuzzle + StoragePad, RamPuzzle + RamGrid, CpuPuzzle + CpuTile
    ui/                   # Ui (shared builders), SlotCard, TierRow, StatBar, TimerBar,
                          # ResultOverlay, ConfirmDialog, HintOverlay, UpgradeCard
  theme/
    hardwire_theme.tres   # colors, font sizes, sizes, durations
  fonts/                  # JetBrains Mono + OFL
  tests/                  # GUT tests: tests/logic/ mirrors logic/ one-to-one
  tools/                  # versions.env, setup.sh, check.sh, drift_check.py (the quality gate),
                          # install_godot.sh, export.sh, deck.sh
```

**Conventions** (enforced by `CLAUDE.md` and `tools/check.sh`):

- Static typing everywhere in GDScript (`var x: int`, typed function signatures).
- Every balance number comes from `Balance`, never a literal in game code.
- Puzzles receive a `SlotDef` and an attempt seed, and emit `solved(result)` or `failed()`; they never touch `GameState` directly.
- Rhythm timing uses `Time.get_ticks_usec()` inside `_input`.
- `tools/check.sh` is the single quality gate (format, lint, drift checks, script errors, tests).
- A debug panel (only in debug builds, opened by tapping the stat bar 5 times within 3 s, or with F1 / gamepad View) can set stats, Cycles and tier, force a minigame and change the time scale. Balancing relies on it. The time scale speeds up playback and timers only; rhythm judging and the CPU input window always use real time, so the minigame stays playable at every scale.

## Milestones and acceptance criteria

Build one milestone per session, in order. Each milestone ends with a playable build and passing tests, so the game can be play-tested at any point. Status lives in `docs/PROGRESS.md`. **M1–M9 are complete (prototype v0.1.0, 2026-10-19, D-026); the Android build is tracked in issue #5.** New work starts from the "After the prototype" sections.

| # | Milestone | Done when |
| --- | --- | --- |
| M1 | Skeleton: project settings, autoloads, `balance.json`, save/load, GUT set up | App opens in a window (portrait on phones, 1280 × 800 landscape on desktop); a debug button adds stats and they survive a restart; tests run headless |
| M2 | Storage minigame, launched from a debug menu with a tier picker | Tiers 1, 5 and 20 play as specified; wrong tap and timeout both start a new sequence; Reverse and Decoy work when forced; generator tests pass |
| M3 | RAM minigame | Toggle, Commit and timeout work; failed attempts flash the answer; Inverted and Rotated work when forced |
| M4 | CPU minigame and `RhythmJudge` | Judge tests cover exact input, input within tolerance, too many presses, and one segment out of tolerance; playing a tier 1 rhythm by ear passes |
| M5 | Overview, slot generation, gating, rewards, Boot and Settings screens, debug panel | Fresh save reaches tier 4 through first solves alone; locked slots show missing stats; numbers match the Sample tiers table |
| M6 | Shop and upgrades | All six upgrades buy, persist and change their puzzle as specified |
| M7 | Prestige and idle income | Rebuild becomes available after a tier 10 solve; Cores and multiplier are correct; the right fields reset; idle Cycles are offered after closing the app for over 5 minutes and respect the 8 h cap |
| M8 | Polish and export | Synth sounds, haptics, screen transitions, first-run hints; Android APK and web build run on a real phone |
| M9 | Steam Deck and desktop: landscape layouts, gamepad and keyboard controls, Linux build | The Linux build runs fullscreen in Steam Deck game mode; every screen and minigame is playable with the controller alone and with touch alone; landscape layouts work at 16:10 and 16:9; prompts show glyphs of the last-used device; export presets exist for Windows and macOS; CI builds Linux and Windows |

## After the prototype: Steam release

Hardwire is meant to go on Steam eventually as a paid game; the price is set in Steamworks at
launch (D-031). That needs a Steamworks app (one-time app fee), builds uploaded with SteamPipe, a default Steam Input configuration matching the Controls table, and a Steam Deck Verified review (full controller support, 1280 × 800 layout, readable text, no launcher). M9 prepares everything except the Steamworks account.

## After the prototype: Benchmark slot

Every tier divisible by 5 gets a fourth slot, the Benchmark, which chains all three minigames into one run. It is built after M8; the prototype only has to keep the puzzle code chainable.

- **Run:** Storage, then RAM, then CPU, each at that tier's difficulty and without modifiers, with a 1 s "Next test" transition between them.
- **Failure:** any failure restarts the whole chain from Storage with fresh content.
- **Requirement:** the tier's normal requirement on all three stats.
- **Reward:** `reward(T)` to each of RAM, CPU and STO, plus 3 × `cycles(T)`; the first solve pays double, as usual.
- **Optional:** the Benchmark never gates the next tier; it is the most efficient grind and a visible milestone.
- **Look:** a wider card spanning the tier row, labelled "Benchmark" with all three stat colors.
- **Prototype requirement:** `PuzzleBase` must accept a `SlotDef` and emit `solved`/`failed` without owning the screen, so a `ChainPuzzle` can run three puzzles in sequence later without refactoring.

## Decisions and balancing notes

All open questions are decided as of 2026-10-19; the numbers in this spec are still first guesses meant to be tuned in play-testing.

- Game name: Hardwire. Confirm availability when reserving it in Google Play Console and App Store Connect.
- Idle income: Cycles only, capped at 8 hours (see Idle income).
- Mixed slot: a Benchmark slot every 5th tier, built after the prototype.
- Monetization beyond the Steam price: none. No ads, in-app purchases or tracking SDKs; the code
  stays open source (MIT).
- iOS builds: Android and web first; iOS later. Since 28 April 2026 App Store uploads need Xcode 26, which needs a recent macOS, so iOS will need a newer Mac or a cloud macOS build service ([Apple](https://developer.apple.com/news/upcoming-requirements/)).

What to watch during play-testing:

- Time to reach tier 5, 10 and 20 on a fresh save. Rough target: 10 minutes, 1 hour, several sessions.
- Fail rate per minigame and tier. If one minigame fails far more often, players will avoid it; adjust its curve rather than the shared economy.
- Whether rhythm tolerance feels fair on a real phone, where touch latency is higher than on desktop.
