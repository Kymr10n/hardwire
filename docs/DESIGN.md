# Hardwire — Cold Boot design language

As of 2026-10-21 (D-039). The one home for how Hardwire looks. `docs/SPEC.md` says what each screen contains; this file says how it is drawn. Every value below lives in `theme/hardwire_theme.tres` under the `Hardwire` type; code reads it by name and never repeats a colour, size or duration.

## Intent

Hardwire should feel like a real computer being booted, diagnosed, stressed, upgraded and rebuilt. The interface is a purpose-built diagnostic console: cold, utilitarian, precise, slightly worn, credible. It is not a consumer app, a decorative cyberpunk HUD or a fake terminal full of meaningless text. Personality comes from typography, hierarchy, restrained phosphor colour, technical labels and responsive state changes.

## Principles

1. **Function first.** Puzzle state, next action, resources and requirements are legible at a glance, on a phone and on a Steam Deck.
2. **Authentic system language.** Short labels that describe the real state: `SYSTEM READY`, `REBUILD AVAILABLE`, `Write complete`, `Corrupted`. No invented telemetry, serial numbers or fake logs.
3. **Restrained colour.** Phosphor green is the one UI accent. Amber is an occasional attention signal. Red is failure only. The three stat hues mark module identity and nothing else.
4. **Never colour alone.** Every state is also said by text, shape or position (a tag, a label, a filled vs outlined marker).
5. **Hard edges, clear structure.** Square panels, thin rules, aligned columns, deliberate negative space. No pills, bevels, gradients, glows, shadows, textures or shaders.
6. **Motion has meaning.** Animate state changes, progress and feedback only. No idle pulsing, flashing or decorative effects.
7. **Preserve the game.** This is presentation only: gameplay, balance, saves, input and architecture are untouched.

## Tokens

| Theme name | Value | Role |
| --- | --- | --- |
| `bg` | `#090C0B` | window background, dim layers behind dialogs |
| `card` | `#101613` | panels, cards, buttons, idle RAM cells |
| `card_locked` | `#0C110E` | locked cards and disabled buttons (recessed) |
| `raised` | `#171F1A` | pressed and active surfaces |
| `trace` | `#344239` | outlines, rules, the tier trace line, the timer track |
| `text` | `#D8E2D9` | primary text, values |
| `text_dim` | `#87958A` | labels, metadata, met requirements, hints, hover border, idle beat marker outlines, outlined tags |
| `accent` | `#8CFF9B` | phosphor: focus ring, pressed border, `Your turn`, success, `SYSTEM READY`, purchase flash |
| `warn` | `#E6B65C` | attention: unmet requirement chips, `REBUILD AVAILABLE`, the enabled Rebuild button and its confirm button |
| `fail` | `#FF6B61` | failure: `Corrupted`, the missed beat marker, Reset save / Erase |
| `disabled` | `#536057` | disabled button text and border |
| `ram` | `#5FD3E6` | RAM identity: stat value, card and header title, timer fill, lit cells, rotation arrow |
| `cpu` | `#B48CFF` | CPU identity: stat value, titles, timer fill, the tile, filled beat markers |
| `sto` | `#FF9E57` | STO identity: stat value, titles, timer fill |
| `pad_0` … `pad_7` | unchanged | Storage pads: colorblind-safe palette, each with a symbol (gameplay) |

Sizes and durations (`constants`, `font_sizes`) are listed in the theme itself; the ones the look depends on are `glow_ms` 80, `glow_scale_pct` 105, `transition_ms` 150, `boot_line_ms` 250, `outline_width` 2, `outline_new_width` 3, `trace_width` 3 (the tier trace line), `tag_pad` 8, `tap_min` 120, `margin` 48 and the panel padding of 36 in the `panel` style box.

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
- Tags (NEW, LOCKED, Lv n/m) are small square labels: filled (`accent` or stat hue, text in `bg`) for a positive state, outlined `text_dim` for a passive one.

## Motifs

- The tier trace: a thin `trace` line down the left of the overview list with a small square node at each tier label.
- Status lamps and ticks: small squares (the CPU beat markers, tag squares).
- Status line: one short uppercase label in the accent colour that names the real state.

## Vocabulary in use

| Where | Text | Colour |
| --- | --- | --- |
| Boot | `SAVE LOADED` / `NEW SYSTEM`, `CORES n`, `BEST TIER n` | `text_dim` |
| Boot, overview header | `SYSTEM READY` | `accent` |
| Overview header | `REBUILD AVAILABLE` | `warn` |
| Puzzle phase | `3`, `2`, `1`, `Watch` | `text_dim` |
| Puzzle phase | `Your turn`, `Write complete` | `accent` |
| Puzzle phase | `Corrupted` | `fail` |
| Slot card | `NEW` (filled stat hue), `LOCKED` (outlined) | see Geometry |
| Shop | `Lv n/m` tag | `text_dim` |
| Shop | `Max` (the capped buy button) | `disabled` |

## Screens

- **Boot:** title in `text`, subtitle `text_dim`, the check list, the prompt; firmware line bottom-right. Any press starts the game, also mid-list.
- **Overview:** header line (`HARDWIRE` left, status right) over a rule, the stat readout in stat hues, tier rows (`T6`, a rule, requirement chips: `warn` while unmet, `text_dim` when met), three cards per row, bottom bar. The Rebuild button text turns `warn` when it is enabled.
- **Puzzle:** header title in the stat hue, phase label uppercase coloured by phase, timer bar in the stat hue on `trace`; the puzzle is the brightest thing on screen. Success overlay title in `accent`.
- **Shop:** balance in the header, one card per upgrade with a level tag, the effect line in `text_dim`, the buy button carrying the cost; a purchase flashes the card border `accent` for `glow_ms`.
- **Dialogs:** square panel, uppercase title; the confirm button is `warn` for Rebuild and `fail` for Erase.

## Acceptance checklist

- [ ] Reads as a diagnostic terminal: dark green-grey surfaces, thin outlines, square geometry, no rounded corners anywhere.
- [ ] Green is the only UI accent; amber appears only on unmet chips, the rebuild status, the enabled Rebuild button and its confirm; red only on failure and destructive actions.
- [ ] RAM, CPU and STO stay distinguishable by hue, name and symbol.
- [ ] Every state is readable without colour (tags, labels, filled vs outlined).
- [ ] Focus ring visible with keyboard and gamepad on every screen; hit targets keep `tap_min`.
- [ ] No clipped text or layout shift at 540 × 960 and 1280 × 800.
- [ ] No new assets, shaders or dependencies; all values in the theme.
