# Beige Box — Design Guide for *Hardwire: Boot Sequence*

**Concept in one line:** the game you are playing *is* the junk computer. Every screen is a part of a beat-up 90s beige tower — yellowed plastic case, silkscreen labels, drive bays, LEDs under frosted plastic. Upgrading your stats means physically stuffing the machine with better parts.

This guide defines the visual language so that the theme, shaders, scenes and copy are built consistently. It is a peer of `docs/SPEC.md`: change this document first (with a `docs/DECISIONS.md` entry), then the code. Adopted by D-039, which also lists what is deferred (see §9).

---

## 1. Design pillars

1. **The case is the UI.** Panels are plastic panels, rows are drive bays, buttons are keycaps and switches. Nothing floats: everything is mounted on something.
2. **Light comes from LEDs, not from the palette.** Beige plastic is warm and dull; the only saturated colors are glowing LEDs and lit pads. Color = electricity.
3. **Wear sells the story.** Yellowed plastic, scratches, screw heads, peeling stickers. The machine has been dragged through three garage sales — and you're bringing it back.
4. **Progress is visible hardware.** Higher tiers = visibly better components slot into the case. Prestige ("Rebuild") is a full teardown on a dirty workbench. *(Deferred, see §9.)*
5. **Squares over curves.** Corner radius is 0 almost everywhere. The only curves are LED domes and screw heads.

---

## 2. Color system

Two families: **Plastic** (surfaces, borders, text — never saturated) and **Electric** (LEDs, pads, feedback — the only saturated colors allowed).

### 2.1 Plastic family (surfaces & text)

| Token | Hex | Theme role | Use |
| --- | --- | --- | --- |
| `case_front` | `#D8CBB0` | `bg` | Main panel surface — sun-yellowed beige |
| `case_side` | `#C4B696` | `card` | Secondary surface, drive bays, keycaps |
| `case_shade` | `#8F8677` | `card_locked` | Deep plastic recesses, vent slits, blanking plates, dim overlays |
| `plastic_light` | `#EDE3CE` | `plastic_light` | Bevel highlight edges (top-left light) |
| `plastic_dark` | `#6E685B` | `plastic_dark` | Bevel shadow edges (bottom-right dark) |
| `silk` | `#4A4436` | `text` | Silkscreen text & labels on plastic |
| `silk_dim` | `#837B69` | `text_dim` | De-emphasized labels, footnotes, plate stamps |
| `metal` | `#9C9C9C` | `metal` | Screws, drive faces, cell outlines |
| `metal_dark` | `#5A5A5A` | `metal_dark` | Screw slots, outlines, vent slits |

### 2.2 Electric family (feedback only)

| Token | Hex | Theme role | Use |
| --- | --- | --- | --- |
| `led_green` | `#3FBF4A` | `led_green` | Stat LED banks; success; confirmation |
| `led_amber` | `#FFB000` | `led_amber` | Focus LED; Cycles readout; attention |
| `led_red` | `#D03A2B` | `fail` | Failure; destructive actions |
| `sto_glow` | `#E8A33D` | `sto` | Storage accent (warm drive LED) |
| `ram_glow` | `#59C8E8` | `ram` | RAM accent (cool diagnostics LED) |
| `cpu_glow` | `#E8593D` | `cpu` | CPU accent (heat / turbo LED) |

**Rules of use**

- Electric colors *never* fill large surfaces. They appear as small LED dots, glowing pad cores, thin lit border segments (the accent border of a never-solved slot card), and readout text.
- Every Electric color used as a glow sits over the Plastic family — glow on beige reads as light through frosted plastic, which is the whole look.
- The 8 pad colors are **LED tints** (§5.2): saturated but dusty (LED + plastic diffusion), never candy.

### 2.3 Theme mapping

The theme keeps its role names; only the values changed. `trace` was removed (its uses became `metal_dark`). Hex values are converted to `Color(r, g, b)` in `theme/hardwire_theme.tres`, the single home of every color.

> The background is **light**. Gritty ≠ dark: grime reads best on sun-yellowed beige under a desk lamp. A dark "Night Shift" skin is a possible later variant — do not design for both at once.

---

## 3. Shape language & surfaces

### 3.1 Corners

- Corner radius **0** on all panels, buttons, cards, pads, cells, bars and stickers.
- Exceptions: LED indicators (circles), screw heads (circles, `screw_size` 16 px), rounded tap markers (bar LEDs stay rectangular).

### 3.2 Bevels — the core surface treatment

Every raised element uses a classic plastic bevel of `bevel` (2 px) width, drawn by one scripted stylebox (`BevelBox`):

```
Raised (keycaps, cards, panels):        Recessed (pads, grids, bars, screens):
  top/left  edge = plastic_light          top/left  edge = plastic_dark
  bottom/right   = plastic_dark           bottom/right   = plastic_light
  fill = case_front or case_side          fill = case_shade
  1 px metal_dark outline                 1 px metal_dark outline
```

Panels and drive-bay cards add **screws in two opposite corners** (§6.3).

### 3.3 Texture & wear

One cheap full-screen overlay shader (`theme/wear.gdshader`), above every screen:

- **Grain**: subtle per-pixel brightness noise (~3–4% amplitude, static). Sells "plastic, not flat vector".
- **Scuffs**: a handful of long thin low-alpha streaks at shallow angles, never vertical.
- **Yellowing**: a subtle darkening towards the corners — old cases yellow unevenly.

Keep all three subtle. If wear is the first thing you notice, it's 2× too strong.

---

## 4. Typography

### 4.1 Faces (two roles only)

| Role | Face | Notes |
| --- | --- | --- |
| **Silkscreen / labels** | VT323 (OFL) | The default font. ALL CAPS for titles, headers, phase labels, button captions, stat labels, stickers; sentence case for body text |
| **Machine readout** | DSEG14 Classic (OFL) | Numbers only: stat values, Cycles, prices. DSEG14 (not DSEG7) because compact numbers carry a K or M suffix |

JetBrains Mono is retired — it reads "modern IDE", which breaks the 1994 fiction.

### 4.2 Sizes & casing (`Hardwire/font_sizes/*`)

| Element | Size | Face | Case |
| --- | --- | --- | --- |
| `title` (Boot subtitle; the Boot title is drawn at 2×) | 64 | Silkscreen, +4 px letter-spacing (`Hardwire/fonts/title`) | ALL CAPS |
| `header` (screen titles) | 40 | Silkscreen | ALL CAPS |
| `phase` (minigame prompts) | 56 | Silkscreen | ALL CAPS |
| `card_title` (card and dialog titles) | 36 | Silkscreen | ALL CAPS on stickers |
| `body`, `card_body` | 32 | Silkscreen | Sentence case |
| `small` (stickers, part numbers, chips) | 32 | Silkscreen | ALL CAPS, `silk_dim` |
| `readout` (shop prices, balance) | 48 | DSEG14 | Digits |
| `readout_small` (stat bar, so four meters fit a phone) | 36 | DSEG14 | Digits |

The spec's 32 px minimum stands (the original guide's 30 px body and 8–10 px stickers were raised; `silk_dim` + caps do the "fine print" job). Silkscreen text on beige uses `silk`. **Never pure black** — beige-era printing was always dark brown or grey.

### 4.3 Label conventions

- Part numbers everywhere: every bay and pad carries a `silk_dim` designator (`BAY 3`, `J7`). This is the cheapest authenticity device in the guide.
- A fine-print footer on the main screens (Overview, Shop, Settings): `HARDWIRE SYSTEMS · MODEL HW-486 · NO USER-SERVICEABLE PARTS INSIDE`.

---

## 5. Components

### 5.1 Buttons — "keycaps"

- Surface: `case_side` fill, raised bevel, 1 px `metal_dark` outline, radius 0.
- Caption: silkscreen, ALL CAPS, `silk`.
- Pressed: bevel recessed, content down 2 px, fill darkened 8%. This is the tactile core of the theme — a keycap going *in*. Release snaps back.
- Focus (gamepad/keyboard): **a physical, not glow, treatment** — a `led_amber` LED dot of radius `led_size` / 2 at the keycap's top-right corner (set on the theme's focus style). The focused element is the one whose LED is on; it never shows for pointer input.
- Disabled: fill `case_shade`, caption `silk_dim`.

### 5.2 Pads (Storage minigame) — "LEDs under frosted plastic"

- Shape: **square**, radius 0, recessed bevel, fill `case_shade`. The glow is drawn *inside* the pad as a soft radial gradient of the pad tint (the theme's `glow` icon), not as a border or a fill.
- Idle: `pad_idle_pct` (30%) glow. Lit: full glow, scaled to `glow_scale_pct` with a slight overshoot that settles over `glow_ms`.
- Pressed (held): the pad recesses 2 px (keycap press) for as long as it glows, at least `tap_flash_ms`.
- Decoy: glows at `decoy_pct` (20%) and **flickers** (blinks every `glow_ms`) — an LED with a bad solder joint, "half-alive" rather than "a different color".
- Each pad carries a `J n` designator. The 8 pad tints, all verified to glow on beige:

```
0 #E8A33D amber      1 #59C8E8 cyan       2 #7FD48A green     3 #E8D759 yellow
4 #7C93E0 blue       5 #E0714A orange     6 #D07C9C pink      7 #C9C2B4 warm white
```

### 5.3 Cards (slot cards) — "drive bay devices"

- Card = a **bay device**: `case_side` face plate with screws, a recessed `case_shade` screen area showing the info, the stat accent as title color, a `BAY n` designator.
- Never solved: accent-colored border (a lit border segment) and a square `NEW` sticker.
- Locked: the face plate is a **blanking panel** — `case_shade` fill, no screen, the missing stats and a stamped `EMPTY BAY` label below them. Locked must look *physically absent*, not greyed-out.
- Pressed: bevel flips, content shifts down 2 px.

### 5.4 Panels & dialogs — "case panels"

- Dialogs are **face plates screwed over the screen**: `case_front` fill, outline + bevel, screws, title as a silkscreen strip with a thin `silk_dim` underline rule.
- Overlay dim (`overlay_dim_pct`, `dialog_dim_pct`): tint towards `case_shade`, not black — like the screen being covered by plastic.
- The Rebuild dialog alone wears a yellow-black hazard-stripe border (scarcity keeps it special).

### 5.5 Stat bar — "front panel"

- Background: `case_side` bevelled panel, separated from the content by a vent slit row (§6.2).
- Each stat: silkscreen label, a readout in DSEG, and a **bank of 10 LED dots**: lit = `led_green`, empty = `case_shade` with a `silk_dim` ring. The bank shows progress from the current tier's requirement to the next tier's (`Progress.tier_leds`).
- Cycles: a DSEG readout in `led_amber` at the end — the HDD-activity light of the whole UI: it pulses once whenever Cycles change. Cores: a dim readout.

### 5.6 Minigame surfaces

- **RAM**: the grid sits in a `case_shade` recess; cell outlines in `metal`; lit cells glow in the RAM accent.
- **CPU**: the tile is one big square switch (raised; lit or held = recessed with the CPU glow). Beat markers are LEDs: round for taps, rectangular bar LEDs for holds, `led_red` for the missed beat, dark rings when unlit.
- **Timer bar**: a rectangular recess with a glowing fill in the stat accent.

---

## 6. Authenticity kit

### 6.1 Stickers & stamps

`silk_dim`, ALL CAPS, `small` size: the footer line (§4.3), `EMPTY BAY`, `NEW`, part numbers on upgrade cards (`PN` + a short code).

### 6.2 Vent slits

Rows of short `metal_dark` lines, `vent_slit_h` (2 px) tall, with gaps (`Deco.vent()`), used as section separators under the front panel and between tier rows. Cheaper and more in-world than divider lines.

### 6.3 Screws

- Circle `metal` fill, `metal_dark` outline, one straight slot line. Size `screw_size` (16 px).
- Screws sit in two opposite corners of panels and cards. Their rotation is pseudo-random but deterministic (hashed from the rect and corner), so a screen full of identically-oriented screws never happens and tests stay stable.

---

## 7. Motion

| Event | Motion | Timing |
| --- | --- | --- |
| Pad lights | Scale to 105% with a back-ease overshoot, settle | `glow_ms` (80 ms) |
| Pad press | Glow *plus* a 2 px recess (keycap press) | at least `tap_flash_ms` (180 ms) |
| Keycap press | Bevel flips to recessed, content 2 px down | instant, both ways |
| Screen transitions | Fade in | `transition_ms` (150 ms) |
| Cycles change | Readout pulses once | `tap_flash_ms` |
| Decoy | Blinks between `decoy_pct` and off | every `glow_ms` |

Motion rule: **nothing eases over more than 250 ms.** 90s hardware snaps.

---

## 8. Screen-by-screen notes

| Screen | Treatment |
| --- | --- |
| **Boot** | Title in silk with letter-spacing, dim subtitle and prompt, firmware line in the corner |
| **Overview** | Front panel (stat bar) and vent row; tier rows as drive-bay stacks separated by vents; keycap bar; fine-print footer |
| **Storage** | A keypad of LED pads with `J n` designators |
| **RAM** | A bare PCB window: the grid in a recess with metal cell outlines |
| **CPU** | One big square switch and an LED strip for the beats |
| **Shop** | `PARTS & UPGRADES`: each upgrade is a line item with a part number, a DSEG price and a `BUY` keycap (`MAX` when maxed); fine-print footer |
| **Settings** | Keycaps in a grid; fine-print footer |
| **Rebuild dialog** | The hazard-stripe face plate |

---

## 9. Implementation status

Done (D-039): palette and shapes, fonts, wear overlay, screws and vents, LED system (banks, focus LED, pad glow), keycap press feel, stickers and part numbers, decoy flicker, pad overshoot, Rebuild hazard border.

Remaining steps, each with a scope and "Done when" in the spec section "After the prototype: Beige Box, remaining steps" (D-041): the power-cycle screen transition, physical sound effects and a lo-fi pass on the score, progress-as-hardware with the Rebuild teardown, the Boot power switch, the Night Shift skin, the overview vent column and the icon.

### Definition of done (screen review checklist)

- [ ] Zero rounded corners anywhere (except LEDs and screws)
- [ ] Every panel has at least one screw or sticker; screws are at different angles
- [ ] No pure black or pure white anywhere on screen
- [ ] Saturated color only inside LEDs, glows and readouts; surfaces stay dusty beige
- [ ] Every interactive element has a physical press response
- [ ] Locked content looks *physically absent*, not greyed-out
- [ ] Footer fine print present on the main screens
- [ ] No transition longer than 250 ms
- [ ] Minimum font size 32 px at the reference size
