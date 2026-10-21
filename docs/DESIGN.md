# Hardwire — Cold Boot design language

As of 2026-10-21 (D-039, D-041). The one home for how Hardwire looks. `docs/SPEC.md` says what each screen contains; this file says how it is drawn. Every value below lives in `theme/hardwire_theme.tres` under the `Hardwire` type; code reads it by name and never repeats a colour, size or duration.

## Intent

Hardwire should feel like a real computer being booted, diagnosed, stressed, upgraded and rebuilt, seen through the glass of a powered-on monitor. The interface is a purpose-built diagnostic console: cold, utilitarian, precise, slightly worn, credible, and alive: it hums, clicks and glows. It is not a consumer app, a decorative cyberpunk HUD or a fake terminal full of meaningless text. Personality comes from typography, hierarchy, restrained phosphor colour, technical labels and responsive state changes.

## Principles

1. **Function first.** Puzzle state, next action, resources and requirements are legible at a glance, on a phone and on a Steam Deck.
2. **Authentic system language.** Short labels that describe the real state: `SYSTEM READY`, `REBUILD AVAILABLE`, `Write complete`, `Corrupted`. No invented telemetry, serial numbers or fake logs.
3. **Restrained colour.** Phosphor green is the one UI accent. Amber is an occasional attention signal. Red is failure only. The three stat hues mark module identity and nothing else.
4. **Never colour alone.** Every state is also said by text, shape or position (a tag, a label, a filled vs outlined marker).
5. **Hard edges, clear structure.** Square panels, thin rules, aligned columns, deliberate negative space. No pills, bevels, gradients, shadows or textures. The one shader is the glass overlay (below); nothing else glows.
6. **Motion has meaning.** Animate state changes, progress and live state: a count-up, a lamp flash, a blinking cursor or status square during input, the glass's slow breath. Nothing blinks faster than 2 Hz; no flashing, no decorative effects.
7. **Preserve the game.** This is presentation only: gameplay, balance, saves, input and architecture are untouched.

## Tokens

| Theme name | Value | Role |
| --- | --- | --- |
| `bg` | `#070B08` | window background, dim layers behind dialogs |
| `card` | `#0D140F` | panels, cards, buttons, idle RAM cells, spent timer blocks |
| `card_locked` | `#0A100C` | locked cards and disabled buttons (recessed) |
| `raised` | `#15201A` | pressed and active surfaces |
| `trace` | `#2F4A37` | outlines, rules, the tier trace line and nodes, card traces, the bezel frame |
| `text` | `#CFE8D0` | primary text, values (pale phosphor) |
| `text_dim` | `#6FA076` | labels, metadata, met requirements, hints, hover border, idle beat marker outlines, outlined tags |
| `accent` | `#8CFF9B` | phosphor: focus ring, pressed border, `Your turn` and its status square, success, `SYSTEM READY` and its cursor, purchase flash, readout lamp flash, solved tier nodes, bezel pulse on success, dialog title strips |
| `warn` | `#E6B65C` | attention: unmet requirement chips, `REBUILD AVAILABLE`, the enabled Rebuild button and its confirm button |
| `fail` | `#FF6B61` | failure: `Corrupted`, the missed beat marker, the bezel pulse on failure, Reset save / Erase and its title strip |
| `disabled` | `#536057` | disabled button text and border |
| `ram` | `#5FD3E6` | RAM identity: stat value, card and header title, timer fill, lit cells, rotation arrow |
| `cpu` | `#B48CFF` | CPU identity: stat value, titles, timer fill, the tile, filled beat markers |
| `sto` | `#FF9E57` | STO identity: stat value, titles, timer fill |
| `pad_0` … `pad_7` | unchanged | Storage pads: colorblind-safe palette, each with a symbol (gameplay) |

Sizes and durations (`constants`, `font_sizes`) are listed in the theme itself; the ones the look depends on are `glow_ms` 80, `glow_scale_pct` 105, `transition_ms` 150, `pulse_ms` 400 (bezel), `blink_ms` 500 (cursor and status square half period), `boot_char_ms` 18, `lamp_size` 16, `timer_segments` 24, `outline_width` 2, `outline_new_width` 3, `trace_width` 3 (the tier trace line), `tag_pad` 8, `tap_min` 120, `margin` 48 and the panel padding of 36 in the `panel` style box.

## Typography

- One font: JetBrains Mono (SIL OFL). Monospace digits keep values from jittering.
- Status and phase labels are drawn uppercase (`Label.uppercase`): the boot check lines, the overview header and status, the puzzle phase label, dialog and result titles. The strings in code stay in sentence case so tests and messages read naturally. Screen titles, tier labels, body, hints and dialog messages stay normal case.
- Hierarchy comes from size and colour (`text` vs `text_dim`), never from weight, glow or letter spacing.
- Minimum font size is the spec's 32 px at the reference size.

## Geometry and surfaces

- Corner radius 0 on every style box and drawn shape: buttons, panels, cards, tags, pads, cells, tile, markers, timer bar, focus ring.
- Outlines are `outline_width` (2 px) in `trace`: style boxes, cards, idle RAM cells, outlined tags; a NEW card uses `outline_new_width` (3 px) in its stat hue; the focus ring is 3 px `accent` drawn 4 px outside the control.
- Buttons: normal `card` with `trace` border; hover border `text_dim`; pressed `raised` with `accent` border and `accent` text; disabled `card_locked` with `disabled` border and text.
- Rules are Godot `HSeparator`s in `trace`.
- Tags (NEW, LOCKED, Lv n/m, dialog title strips) are square labels padded by `tag_pad` sideways and half of it vertically: filled (`accent` or stat hue, text in `bg`) for a positive state, outlined `text_dim` for a passive one.

## Glass (D-041)

One canvas shader, `theme/glass.gdshader`, on a canvas layer above every screen and dialog (`Main._add_glass`). It reads the finished frame and returns it processed, so it can both darken and glow in one pass:

| Theme constant | Value | Effect |
| --- | --- | --- |
| `glass_vignette_pct` | 35 | radial darkening towards the corners; always on |
| `glass_scanline_pct` | 8 | depth of a cosine trough every `glass_scanline_px` (4) content pixels |
| `glass_bloom_pct` | 25 | bright pixels bleed into four neighbours two pixels away |
| `glass_flicker_pct` | 2 | brightness breath with a `glass_flicker_period_ms` (770, about 1.3 Hz) period |

The Settings toggle "CRT glass" (`settings.crt`, default on) zeroes scanlines, bloom and flicker; the vignette stays. Off still pays the one screen read; a second shader without it is the escape hatch if a device needs it. Pitch is in content pixels, so the Deck and phones show the same lines relative to the UI.

## Sound (D-041)

All from `Synth`, tuned in `balance.json` → `audio`: a low-pass-filtered noise hum (`hum_*`) that runs with the ambient score on the Overview and Puzzle screens; a key click on every button (`key_*`, hooked once for every `BaseButton`); a relay click that drops in pitch on every puzzle phase change (`relay_*`); a tick every other typed boot character (`tick_*`); a low power-on sweep with a soft noise burst when the Boot screen opens (`boot_*`). The RAM toggle keeps its click (`click_*`). Everything respects the Sound setting.

## Motifs

- The board: a thin `trace` line down the left of the overview list, a square node per tier (outlined while locked, filled once open, `accent` once all three slots are solved) with a stub to its label, and thin traces between the three cards.
- Status lamps and ticks: small squares (`lamp_size`): the readout lamp per value, the puzzle status square (solid while watching, blinking during input), the CPU beat markers, tag squares.
- The bezel: a `trace` frame with `text_dim` corner ticks around the puzzle area; it pulses `accent` on success and `fail` on failure and fades back over `pulse_ms`.
- The segmented timer: `timer_segments` blocks in the stat hue, spent blocks `card` with a `trace` outline; the last block stays until time is up.
- Terminal text: dotted leaders in the boot checks (`Memory check ..... RAM 140 OK`), a block cursor after the typed line and after the overview status, inverted title strips on dialogs.
- Status line: one short uppercase label in the accent colour that names the real state.

## Vocabulary in use

| Where | Text | Colour |
| --- | --- | --- |
| Boot | `MEMORY CHECK .... RAM n OK`, `CLOCK .... CPU n OK`, `STORAGE .... STO n OK`, `CORES n  BEST TIER n`, `SAVE LOADED` / `NEW SYSTEM` | `text_dim` |
| Boot, overview header | `SYSTEM READY` | `accent` |
| Overview header | `REBUILD AVAILABLE` | `warn` |
| Puzzle phase | `3`, `2`, `1`, `Watch` | `text_dim` |
| Puzzle phase | `Your turn`, `Write complete` | `accent` |
| Puzzle phase | `Corrupted` | `fail` |
| Slot card | `NEW` (filled stat hue), `LOCKED` (outlined) | see Geometry |
| Shop | `Lv n/m` tag | `text_dim` |
| Shop | `Max` (the capped buy button) | `disabled` |

## Screens

- **Boot:** the power-on sweep, the title fading in over the first typed line, subtitle `text_dim`, the check list typing behind a block cursor with a tick per character, the prompt; firmware line bottom-right. Any press starts the game, also mid-list.
- **Overview:** header line (`HARDWIRE` left, status with a blinking cursor right) over a rule, the readout (lamp, dim name, value per stat; lamps flash and values count up on change), tier rows (`T6`, a rule, requirement chips: `warn` while unmet, `text_dim` when met), three cards per row, bottom bar. The Rebuild button text turns `warn` when it is enabled.
- **Puzzle:** header title in the stat hue, a status square and the phase label uppercase coloured by phase, the segmented timer in the stat hue; the puzzle sits inside the bezel and is the brightest thing on screen. The bezel pulses on the result; the success overlay title is `accent`.
- **Shop:** balance in the header, one card per upgrade with a level tag, the effect line in `text_dim`, the buy button carrying the cost; a purchase flashes the card border `accent` for `glow_ms`.
- **Dialogs:** square panel, the title as an inverted `accent` strip (`fail` for Erase); the confirm button is `warn` for Rebuild and `fail` for Erase.
- **Settings:** Sound, Haptics, CRT glass, Licenses, Fullscreen (PC), Reset save.

## Acceptance checklist

- [ ] Reads as a diagnostic terminal: dark green-grey surfaces, thin outlines, square geometry, no rounded corners anywhere.
- [ ] Green is the only UI accent; amber appears only on unmet chips, the rebuild status, the enabled Rebuild button and its confirm; red only on failure and destructive actions.
- [ ] RAM, CPU and STO stay distinguishable by hue, name and symbol.
- [ ] Every state is readable without colour (tags, labels, filled vs outlined).
- [ ] Focus ring visible with keyboard and gamepad on every screen; hit targets keep `tap_min`.
- [ ] No clipped text or layout shift at 540 × 960 and 1280 × 800.
- [ ] Glass: text stays crisp under the scanlines at 1280 × 800 and 540 × 960; the flicker is felt, not seen; "CRT glass: Off" leaves only the vignette.
- [ ] Sound: the hum is only audible in a quiet room; clicks never stack into noise; everything is silent with Sound off.
- [ ] No image assets or dependencies; one shader; all values in the theme or `balance.json` → `audio`.
