# Changelog

All notable changes to Hardwire are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

First playable prototype (0.1.0).

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
