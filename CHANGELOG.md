# Changelog

All notable changes to Hardwire are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- One-click Steam Deck install: download `Hardwire-SteamDeck.desktop` from the latest release, double-click it in Desktop Mode; it installs or updates the game and adds it to Steam. Releases are published by pushing a `v<version>` tag.

## [0.2.0] - 2026-10-19

Renamed to *Hardwire: Boot Sequence*, with an ambient score, hold feedback on the Storage pads and the groundwork for a Steam release.

### Changed

- Storage: a pressed pad stays lit, sounds its note and rumbles for as long as it is held.
- Renamed to "Hardwire: Boot Sequence" (Boot screen subtitle, window title, Windows exe); the save folder stays `Hardwire`.
- CPU minigame judged as you play: the first beat out of tolerance ends the attempt at once with a red marker and the reason ("Beat 3 too late"); success shows at the last release; tolerance widened to 40% at tier 1 (25% floor, 100 ms minimum).
- Swiping over the slot cards scrolls the overview; a wobbly tap is still a tap.
- Per-frame UI code replaced by Godot built-ins: tweened reward count-up and pad flash, the overview scrolls to the newest tier on layout, the timer is a `ProgressBar`, and pads, grid, stat bar and the first-run hint take pointer input through `_gui_input`.
- Desktop saves move to a `Hardwire` folder (`~/.local/share/Hardwire`, `%APPDATA%\Hardwire`); the Windows exe carries the game icon and version info. Saves from 0.1.0 are not moved: copy `save.json` from `godot/app_userdata/Hardwire` by hand.
- Audio mixes at 22.05 kHz (every tone stays well below half of it).
- The quality gate runs Godot with a throwaway data directory, so it never touches the developer's save; CI exports all platforms in one job.

### Added

- The Boot screen shows the version as a "FIRMWARE v…" line in the corner.
- Rumble on every button press and while a puzzle plays back: each Storage pad as it lights (decoys weaker) and the RAM pattern while it shows, like the CPU tile.
- `SECURITY.md`.
- A quiet procedural ambient score on the overview and puzzle screens: sine bass, soft upper and high notes, and a half-time beat that builds over the first phrases (kick and hats, then a soft noise snare, then ghost hats).
- `tools/steam_upload.sh`: exports Linux and Windows and uploads them to Steam with SteamPipe.

### Fixed

- A puzzle screen rebuilt mid-attempt (rotation, window resize) no longer leaves a held tone or rumble running.

## [0.1.0] - 2026-10-19

First playable prototype: all nine milestones of the spec, played on desktop and Steam Deck.

### Added

- Storage minigame (color sequence), with the Reverse and Decoy modifiers and the Replay buffer upgrade.
- RAM minigame (pattern grid), with the Inverted and Rotated modifiers.
- CPU minigame (rhythm) with a relative-timing judge, and the Audio only and Syncopated modifiers.
- Endless tier overview with stat gating, first-solve bonuses and deterministic modifier slots.
- Upgrade shop with six upgrades; prestige ("Rebuild") for permanent Cores; idle Cycles for time away (up to 8 hours).
- Boot, Settings and Licenses screens; first-run hints; screen transitions; Android back button.
- Runtime-synthesized audio, haptic feedback, the JetBrains Mono font, and a flat circuit-board theme.
- Local JSON save with atomic writes and backup of broken files.
- Debug panel for balancing (debug builds only).
- Steam Deck and desktop: landscape layouts picked from the window aspect, full gamepad and keyboard controls with a focus outline (hidden for touch) and glyphs for the last-used device, gamepad rumble, fullscreen on the Deck, Fullscreen and Quit in Settings on PC, 60 fps cap.
- Builds for Linux / Steam Deck, Windows, macOS, Android and the web; `tools/deck.sh` deploys to a Steam Deck over SSH.
- CPU rhythm judged on beats and holds, not tap length, with beat-length markers under the tile.
- Controller rumble with the rhythm: the pad buzzes while the CPU tile is lit or held; a double pulse on success and a long pulse on failure.
